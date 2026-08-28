#include "ModernMapProvider.hpp"

#include <cmath>
#include <limits>
#include <utility>

#include <godot_cpp/classes/image.hpp>

using namespace godot;

namespace OpenVic {

static constexpr int32_t GPU_DIM_LIMIT = 0x3FFF;
static constexpr int32_t MAX_RENDERABLE_PROVINCE_NUMBER = 0xFFFF;
static constexpr int32_t MODERN_TERRAIN_LAYER_COUNT = 256;

static Ref<Image> make_rgb8_image(
uint8_t const red,
uint8_t const green,
uint8_t const blue
) {
PackedByteArray data;

if (data.resize(3) != OK) {
return Ref<Image>();
}

data[0] = red;
data[1] = green;
data[2] = blue;

return Image::create_from_data(
1,
1,
false,
Image::FORMAT_RGB8,
data
);
}

static Ref<ImageTexture> make_rgb8_texture(
uint8_t const red,
uint8_t const green,
uint8_t const blue
) {
Ref<Image> const image = make_rgb8_image(red, green, blue);

if (image.is_null()) {
return Ref<ImageTexture>();
}

return ImageTexture::create_from_image(image);
}

Error ModernMapProvider::load(
Vector2i const& new_dims,
PackedInt32Array const& new_province_number_raster,
PackedStringArray const& new_stable_external_ids
) {
if (new_dims.x <= 0 || new_dims.y <= 0) {
return ERR_INVALID_PARAMETER;
}

int64_t const expected_raster_size =
static_cast<int64_t>(new_dims.x) * static_cast<int64_t>(new_dims.y);

if (
expected_raster_size <= 0 ||
expected_raster_size > static_cast<int64_t>(std::numeric_limits<int32_t>::max()) ||
new_province_number_raster.size() != expected_raster_size
) {
return ERR_INVALID_PARAMETER;
}

if (
new_stable_external_ids.is_empty() ||
new_stable_external_ids.size() > MAX_RENDERABLE_PROVINCE_NUMBER
) {
return ERR_INVALID_PARAMETER;
}

std::vector<String> validated_ids;
validated_ids.reserve(static_cast<size_t>(new_stable_external_ids.size()));

for (int64_t index = 0; index < new_stable_external_ids.size(); ++index) {
String const stable_id = new_stable_external_ids[index];

if (stable_id.is_empty()) {
return ERR_INVALID_PARAMETER;
}

validated_ids.push_back(stable_id);
}

std::vector<int32_t> validated_raster;
validated_raster.reserve(static_cast<size_t>(expected_raster_size));

int64_t const maximum_province_number = new_stable_external_ids.size();

for (int64_t index = 0; index < new_province_number_raster.size(); ++index) {
int32_t const province_number = new_province_number_raster[index];

// 0 is reserved for no province. Real province numbers are 1..N.
if (
province_number < 0 ||
static_cast<int64_t>(province_number) > maximum_province_number
) {
return ERR_INVALID_PARAMETER;
}

validated_raster.push_back(province_number);
}

/* Derive one deterministic presentation position per visual province.
 *
 * Y uses the arithmetic mean of raster-pixel centres.
 * X uses a circular mean because the modern map wraps horizontally.
 */
size_t const province_count = validated_ids.size();

std::vector<double> sum_sin_x(province_count, 0.0);
std::vector<double> sum_cos_x(province_count, 0.0);
std::vector<double> sum_y(province_count, 0.0);
std::vector<uint64_t> pixel_counts(province_count, 0);

constexpr double tau = 6.283185307179586476925286766559;

for (int32_t y = 0; y < new_dims.y; ++y) {
    for (int32_t x = 0; x < new_dims.x; ++x) {
        size_t const raster_index =
            static_cast<size_t>(x) +
            static_cast<size_t>(y) * static_cast<size_t>(new_dims.x);

        int32_t const province_number = validated_raster[raster_index];

        if (province_number <= 0) {
            continue;
        }

        size_t const province_index = static_cast<size_t>(province_number - 1);

        double const u =
            (static_cast<double>(x) + 0.5) /
            static_cast<double>(new_dims.x);

        double const v =
            (static_cast<double>(y) + 0.5) /
            static_cast<double>(new_dims.y);

        double const angle = u * tau;

        sum_sin_x[province_index] += std::sin(angle);
        sum_cos_x[province_index] += std::cos(angle);
        sum_y[province_index] += v;
        ++pixel_counts[province_index];
    }
}

std::vector<Vector2> centroid_positions;
centroid_positions.reserve(province_count);

for (size_t province_index = 0; province_index < province_count; ++province_index) {
    uint64_t const count = pixel_counts[province_index];

    if (count == 0) {
        return ERR_INVALID_DATA;
    }

    double angle = std::atan2(
        sum_sin_x[province_index],
        sum_cos_x[province_index]
    );

    if (angle < 0.0) {
        angle += tau;
    }

    double const u = angle / tau;
    double const v = sum_y[province_index] / static_cast<double>(count);

    centroid_positions.emplace_back(
        static_cast<float>(u),
        static_cast<float>(v)
    );
}

/* The geometric centroid can fall outside an irregular province.
 * Choose the actual raster-pixel centre nearest to that centroid instead.
 * Horizontal distance is wrapped because the world map wraps at U=0/1.
 */
std::vector<Vector2> validated_positions(
    province_count,
    Vector2 {}
);

std::vector<double> best_distance_squared(
    province_count,
    std::numeric_limits<double>::infinity()
);

for (int32_t y = 0; y < new_dims.y; ++y) {
    for (int32_t x = 0; x < new_dims.x; ++x) {
        size_t const raster_index =
            static_cast<size_t>(x) +
            static_cast<size_t>(y) * static_cast<size_t>(new_dims.x);

        int32_t const province_number = validated_raster[raster_index];

        if (province_number <= 0) {
            continue;
        }

        size_t const province_index =
            static_cast<size_t>(province_number - 1);

        double const u =
            (static_cast<double>(x) + 0.5) /
            static_cast<double>(new_dims.x);

        double const v =
            (static_cast<double>(y) + 0.5) /
            static_cast<double>(new_dims.y);

        Vector2 const centroid = centroid_positions[province_index];

        double delta_u =
            std::abs(u - static_cast<double>(centroid.x));

        delta_u = std::min(delta_u, 1.0 - delta_u);

        double const delta_v =
            v - static_cast<double>(centroid.y);

        double const distance_squared =
            delta_u * delta_u +
            delta_v * delta_v;

        if (distance_squared < best_distance_squared[province_index]) {
            best_distance_squared[province_index] = distance_squared;

            validated_positions[province_index] = Vector2 {
                static_cast<float>(u),
                static_cast<float>(v)
            };
        }
    }
}

// Activate only after all validation and copying have succeeded.
dims = new_dims;
province_number_raster = std::move(validated_raster);
stable_external_ids = std::move(validated_ids);
province_positions = std::move(validated_positions);

// Render data belongs to the loaded map, so a new identity map invalidates
// any texture generated for the previous map.
image_subdivisions = {};
province_shape_texture.unref();
province_colour_texture.unref();
terrain_texture.unref();
stripe_texture.unref();
overlay_texture.unref();
colormap_land_texture.unref();
colormap_water_texture.unref();
colormap_overlay_texture.unref();

active = true;

return OK;
}

Error ModernMapProvider::load_render_data(
PackedByteArray const& terrain_raster
) {
if (
!active ||
dims.x <= 0 ||
dims.y <= 0 ||
province_number_raster.empty() ||
terrain_raster.size() != static_cast<int64_t>(province_number_raster.size())
) {
return ERR_INVALID_PARAMETER;
}

Vector2i new_subdivisions { 1, 1 };

// Match OpenVic's existing subdivision logic so no texture dimension
// exceeds the GPU limit and every subdivision has equal dimensions.
for (int32_t dimension = 0; dimension < 2; ++dimension) {
while (
dims[dimension] / new_subdivisions[dimension] > GPU_DIM_LIMIT ||
dims[dimension] % new_subdivisions[dimension] != 0
) {
++new_subdivisions[dimension];
}
}

Vector2i const divided_dims = dims / new_subdivisions;
int64_t const subdivision_width =
static_cast<int64_t>(divided_dims.x) * 3;
int64_t const subdivision_size =
subdivision_width * static_cast<int64_t>(divided_dims.y);

TypedArray<Image> province_shape_images;

if (
province_shape_images.resize(
static_cast<int64_t>(new_subdivisions.x) *
static_cast<int64_t>(new_subdivisions.y)
) != OK
) {
return FAILED;
}

PackedByteArray index_data_array;

if (index_data_array.resize(subdivision_size) != OK) {
return FAILED;
}

for (int32_t v = 0; v < new_subdivisions.y; ++v) {
for (int32_t u = 0; u < new_subdivisions.x; ++u) {
for (int32_t y = 0; y < divided_dims.y; ++y) {
for (int32_t x = 0; x < divided_dims.x; ++x) {
int32_t const source_x = u * divided_dims.x + x;
int32_t const source_y = v * divided_dims.y + y;

size_t const source_index =
static_cast<size_t>(source_x) +
static_cast<size_t>(source_y) *
static_cast<size_t>(dims.x);

int32_t const province_number =
province_number_raster[source_index];

int64_t const destination_index =
(
static_cast<int64_t>(x) +
static_cast<int64_t>(y) *
static_cast<int64_t>(divided_dims.x)
) * 3;

// Existing shader contract:
// R = low province byte
// G = high province byte
// B = terrain byte
index_data_array[destination_index] =
static_cast<uint8_t>(province_number & 0xFF);

index_data_array[destination_index + 1] =
static_cast<uint8_t>((province_number >> 8) & 0xFF);

index_data_array[destination_index + 2] =
terrain_raster[static_cast<int64_t>(source_index)];
}
}

Ref<Image> const province_shape_subimage =
Image::create_from_data(
divided_dims.x,
divided_dims.y,
false,
Image::FORMAT_RGB8,
index_data_array
);

if (province_shape_subimage.is_null()) {
return FAILED;
}

province_shape_images[
u + v * new_subdivisions.x
] = province_shape_subimage;
}
}

// Province colours use the existing shader's 16-bit province lookup.
// X contains base/stripe pairs for the low byte; Y is the high byte.
static constexpr int32_t COLOUR_TEXTURE_WIDTH = 512;
static constexpr int32_t COLOUR_TEXTURE_HEIGHT = 256;

PackedByteArray colour_data;
if (
colour_data.resize(
static_cast<int64_t>(COLOUR_TEXTURE_WIDTH) *
static_cast<int64_t>(COLOUR_TEXTURE_HEIGHT) * 4
) != OK
) {
return FAILED;
}

// Transparent initially: terrain remains visible until an
// observer-filtered modern map mode supplies province colours.
colour_data.fill(0);

Ref<Image> const new_colour_image = Image::create_from_data(
COLOUR_TEXTURE_WIDTH,
COLOUR_TEXTURE_HEIGHT,
false,
Image::FORMAT_RGBA8,
colour_data
);

if (new_colour_image.is_null()) {
return FAILED;
}

Ref<ImageTexture> const new_colour_texture =
ImageTexture::create_from_image(new_colour_image);

if (new_colour_texture.is_null()) {
return FAILED;
}

// Standalone modern-mode cosmetic fallbacks.
//
// Terrain indices are stored as an unrestricted byte in the map
// texture, so the fallback array covers the complete 0-255 range.
// Every layer currently uses the same neutral grey. The land
// colormap uses the identical value, making the shader's 30%
// terrain/tint mix stable. Water directly uses its tint value.
//
// Stripe blue = 0 selects the base province colour.
// Overlay ~= 0.5 is neutral for the shader's overlay blend.
static constexpr uint8_t NEUTRAL_VALUE = 128;

Ref<Image> const neutral_terrain_image = make_rgb8_image(
NEUTRAL_VALUE,
NEUTRAL_VALUE,
NEUTRAL_VALUE
);

if (neutral_terrain_image.is_null()) {
return FAILED;
}

TypedArray<Image> terrain_images;

if (terrain_images.resize(MODERN_TERRAIN_LAYER_COUNT) != OK) {
return FAILED;
}

for (int32_t index = 0; index < MODERN_TERRAIN_LAYER_COUNT; ++index) {
terrain_images[index] = neutral_terrain_image;
}

Ref<Texture2DArray> new_terrain_texture;
new_terrain_texture.instantiate();

if (
new_terrain_texture.is_null() ||
new_terrain_texture->create_from_images(terrain_images) != OK
) {
return FAILED;
}

Ref<ImageTexture> const new_stripe_texture =
make_rgb8_texture(0, 0, 0);

Ref<ImageTexture> const new_overlay_texture = make_rgb8_texture(
NEUTRAL_VALUE,
NEUTRAL_VALUE,
NEUTRAL_VALUE
);

Ref<ImageTexture> const new_colormap_land_texture = make_rgb8_texture(
NEUTRAL_VALUE,
NEUTRAL_VALUE,
NEUTRAL_VALUE
);

Ref<ImageTexture> const new_colormap_water_texture = make_rgb8_texture(
NEUTRAL_VALUE,
NEUTRAL_VALUE,
NEUTRAL_VALUE
);

Ref<ImageTexture> const new_colormap_overlay_texture = make_rgb8_texture(
NEUTRAL_VALUE,
NEUTRAL_VALUE,
NEUTRAL_VALUE
);

if (
new_stripe_texture.is_null() ||
new_overlay_texture.is_null() ||
new_colormap_land_texture.is_null() ||
new_colormap_water_texture.is_null() ||
new_colormap_overlay_texture.is_null()
) {
return FAILED;
}

Ref<Texture2DArray> new_shape_texture;
new_shape_texture.instantiate();

if (
new_shape_texture.is_null() ||
new_shape_texture->create_from_images(province_shape_images) != OK
) {
return FAILED;
}

// Atomic replacement: only publish after the complete texture exists.
image_subdivisions = new_subdivisions;
province_shape_texture = new_shape_texture;
province_colour_texture = new_colour_texture;
terrain_texture = new_terrain_texture;
stripe_texture = new_stripe_texture;
overlay_texture = new_overlay_texture;
colormap_land_texture = new_colormap_land_texture;
colormap_water_texture = new_colormap_water_texture;
colormap_overlay_texture = new_colormap_overlay_texture;

return OK;
}

Error ModernMapProvider::update_province_colours(
PackedByteArray const& colour_data
) {
static constexpr int32_t COLOUR_TEXTURE_WIDTH = 512;
static constexpr int32_t COLOUR_TEXTURE_HEIGHT = 256;
static constexpr int64_t COLOUR_TEXTURE_BYTES =
static_cast<int64_t>(COLOUR_TEXTURE_WIDTH) *
static_cast<int64_t>(COLOUR_TEXTURE_HEIGHT) * 4;

if (
!active ||
province_colour_texture.is_null() ||
colour_data.size() != COLOUR_TEXTURE_BYTES
) {
return ERR_INVALID_PARAMETER;
}

Ref<Image> const colour_image = Image::create_from_data(
COLOUR_TEXTURE_WIDTH,
COLOUR_TEXTURE_HEIGHT,
false,
Image::FORMAT_RGBA8,
colour_data
);

if (colour_image.is_null()) {
return FAILED;
}

province_colour_texture->update(colour_image);
return OK;
}

bool ModernMapProvider::is_active() const {
return active;
}

int32_t ModernMapProvider::get_width() const {
return dims.x;
}

int32_t ModernMapProvider::get_height() const {
return dims.y;
}

Vector2i ModernMapProvider::get_dims() const {
return dims;
}

int32_t ModernMapProvider::get_province_number_from_uv_coords(
Vector2 const& coords
) const {
if (
!active ||
dims.x <= 0 ||
dims.y <= 0 ||
province_number_raster.empty()
) {
return 0;
}

Vector2 const wrapped = coords.posmod(1.0f);
int32_t const x =
static_cast<int32_t>(wrapped.x * static_cast<float>(dims.x));
int32_t const y =
static_cast<int32_t>(wrapped.y * static_cast<float>(dims.y));

if (x < 0 || x >= dims.x || y < 0 || y >= dims.y) {
return 0;
}

size_t const index =
static_cast<size_t>(x) +
static_cast<size_t>(y) * static_cast<size_t>(dims.x);

if (index >= province_number_raster.size()) {
return 0;
}

return province_number_raster[index];
}

String ModernMapProvider::get_stable_external_id_from_province_number(
    int32_t const province_number
) const {
    if (!active || province_number <= 0) {
        return {};
    }

    size_t const index = static_cast<size_t>(province_number - 1);

    if (index >= stable_external_ids.size()) {
        return {};
    }

    return stable_external_ids[index];
}

PackedStringArray ModernMapProvider::get_stable_external_ids() const {
    PackedStringArray result;

    if (!active) {
        return result;
    }

    if (result.resize(static_cast<int64_t>(stable_external_ids.size())) != OK) {
        return {};
    }

    for (size_t index = 0; index < stable_external_ids.size(); ++index) {
        result[static_cast<int64_t>(index)] = stable_external_ids[index];
    }

    return result;
}


PackedVector2Array ModernMapProvider::get_province_positions() const {
    PackedVector2Array result;

    if (!active) {
        return result;
    }

    if (result.resize(static_cast<int64_t>(province_positions.size())) != OK) {
        return {};
    }

    for (size_t index = 0; index < province_positions.size(); ++index) {
        result[static_cast<int64_t>(index)] = province_positions[index];
    }

    return result;
}

TypedArray<Dictionary> ModernMapProvider::get_province_names() const {
static const StringName identifier_key = "identifier";

TypedArray<Dictionary> result;

if (!active) {
return result;
}

if (
result.resize(
static_cast<int64_t>(stable_external_ids.size())
) != OK
) {
return {};
}

for (size_t index = 0; index < stable_external_ids.size(); ++index) {
Dictionary province;
province[identifier_key] = stable_external_ids[index];
result[static_cast<int64_t>(index)] = province;
}

return result;
}

Vector2i ModernMapProvider::get_province_shape_image_subdivisions() const {
return image_subdivisions;
}

Ref<Texture2DArray> ModernMapProvider::get_province_shape_texture() const {
return province_shape_texture;
}

Ref<ImageTexture> ModernMapProvider::get_province_colour_texture() const {
return province_colour_texture;
}

Ref<Texture2DArray> ModernMapProvider::get_terrain_texture() const {
return terrain_texture;
}

Ref<ImageTexture> ModernMapProvider::get_stripe_texture() const {
return stripe_texture;
}

Ref<ImageTexture> ModernMapProvider::get_overlay_texture() const {
return overlay_texture;
}

Ref<ImageTexture> ModernMapProvider::get_colormap_land_texture() const {
return colormap_land_texture;
}

Ref<ImageTexture> ModernMapProvider::get_colormap_water_texture() const {
return colormap_water_texture;
}

Ref<ImageTexture> ModernMapProvider::get_colormap_overlay_texture() const {
return colormap_overlay_texture;
}

}
