#pragma once

#include <cstdint>
#include <vector>

#include <godot_cpp/classes/global_constants.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/texture2d_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector2i.hpp>

namespace OpenVic {

class ModernMapProvider {
private:
godot::Vector2i dims;
std::vector<int32_t> province_number_raster;
std::vector<godot::String> stable_external_ids;

godot::Vector2i image_subdivisions;
godot::Ref<godot::Texture2DArray> province_shape_texture;
godot::Ref<godot::ImageTexture> province_colour_texture;

bool active = false;

public:
godot::Error load(
godot::Vector2i const& new_dims,
godot::PackedInt32Array const& new_province_number_raster,
godot::PackedStringArray const& new_stable_external_ids
);

godot::Error load_render_data(
godot::PackedByteArray const& terrain_raster
);

bool is_active() const;

int32_t get_width() const;
int32_t get_height() const;
godot::Vector2i get_dims() const;

int32_t get_province_number_from_uv_coords(godot::Vector2 const& coords) const;
godot::TypedArray<godot::Dictionary> get_province_names() const;

godot::Vector2i get_province_shape_image_subdivisions() const;
godot::Ref<godot::Texture2DArray> get_province_shape_texture() const;
godot::Ref<godot::ImageTexture> get_province_colour_texture() const;
};

}