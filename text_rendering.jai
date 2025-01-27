#import "freetype255";

TEXT_VERTEX_SOURCE :: #string DONE
#version 330 core

layout (location = 0) in vec4 vertex; // <vec2 pos, vec2 tex>
out vec2 TexCoords;

uniform mat4 projection;

void main()
{
    gl_Position = projection * vec4(vertex.xy, 0.0, 1.0);
    TexCoords = vertex.zw;
} 

DONE

TEXT_FRAGMENT_SOURCE :: #string DONE

#version 330 core

in vec2 TexCoords;
out vec4 color;

uniform sampler2D text;
uniform vec4 textColor;

void main()
{    
    vec4 sampled = vec4(1.0, 1.0, 1.0, texture(text, TexCoords).r);
    color = textColor * sampled;
}

DONE

autolib_font_library: *FT_Library;

Character :: struct
{
	texture_id: u32;
	size: Vec2(s32);
	bearing: Vec2(s32);
	advance: u32;
}

CharactersTable :: Table(u32, Character);

Text_Renderer :: struct
{
	vao, vbo: u32;
	shader: u32;
	
	characters: CharactersTable;
	font_size: u32;
}

load_characters_table :: (table: *CharactersTable, face: FT_Face)
{
	glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
	for c: 0..127
	{
		if FT_Load_Char(face, xx c, FT_LOAD_RENDER)
		{
			print("Failed to load glyph..\n Continuing...\n");
			continue;
		}
		
		texture: u32;
		glGenTextures(1, *texture);
		glBindTexture(GL_TEXTURE_2D, texture);
		glTexImage2D(
			GL_TEXTURE_2D,
			0,
			GL_RED,
			xx face.glyph.bitmap.width,
			xx face.glyph.bitmap.rows,
			0,
			GL_RED,
			GL_UNSIGNED_BYTE,
			face.glyph.bitmap.buffer
		);
		
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		
		character: Character;
		character.texture_id = texture;
		character.size = Vec2(s32).{face.glyph.bitmap.width, face.glyph.bitmap.rows};
		character.bearing = Vec2(s32).{face.glyph.bitmap_left, face.glyph.bitmap_top};
		character.advance = xx face.glyph.advance.x;
		
		table_set(table, xx c, character);
	}
}

init_text_renderer :: (text_renderer: *Text_Renderer, path: *u8, size: u32)
{
	face: FT_Face;
	FT_New_Face(autolib_font_library, path, 0, *face);
	FT_Set_Pixel_Sizes(face, 0, size);
	
	text_renderer.font_size = size;
	
	text_renderer.shader = create_shader(TEXT_VERTEX_SOURCE, TEXT_FRAGMENT_SOURCE);
	
	load_characters_table(*text_renderer.characters, face);
	
	glGenVertexArrays(1, *text_renderer.vao);
	glGenBuffers(1, *text_renderer.vbo);
	glBindVertexArray(text_renderer.vao);
	glBindBuffer(GL_ARRAY_BUFFER, text_renderer.vbo);
	glBufferData(GL_ARRAY_BUFFER, size_of(float) * 6 * 4, null, GL_DYNAMIC_DRAW);
	glEnableVertexAttribArray(0);
	glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, 4 * size_of(float), null);
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	glBindVertexArray(0);
	
	FT_Done_Face(face);
	//FT_Done_FreeType(ft);
}

size_text :: (text_renderer: *Text_Renderer, text: string) -> Vector2
{
	w: float;
	h: float = -FLOAT32_MAX;
	
	for c: 0 .. text.count-1
	{
		ch := table_find_pointer(*text_renderer.characters, xx text[c]);
		w += (cast(float) ch.size.x);
		ch_h := (cast(float) ch.size.y);
		if ch_h > h
		{
			h = ch_h;
		}
	}
	
	return make_vector2(w, h);
}

/*
draw_text :: (text_renderer: *Text_Renderer, text: string, pos: Vector2, scale: float, color: Vector4)
{
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

	win_dim := get_rect_dim(get_winrect());
	projection := orthographic_projection_matrix(0, win_dim.x, 0, win_dim.y, -1, 1);
	view := identity_of(Matrix4);
	
	gl_set_projection_view_matrix(text_renderer.shader, *projection, *view);
	
	//gl_set_int(text_renderer.shader, "flip", 0);
	gl_set_vector4(text_renderer.shader, "textColor", color);
	glActiveTexture(GL_TEXTURE0);
	glBindVertexArray(text_renderer.vao);
	
	x := pos.x;
	y := pos.y;
	
	for c: 0 .. text.count-1
	{
		if text[c] == xx #char "\n"
		{
			y -= xx text_renderer.font_size * scale;
			x = pos.x;
			continue;
		}
		ch := table_find_pointer(*text_renderer.characters, xx text[c]);
		xpos := x + (cast(float) ch.bearing.x) * scale;
		ypos := y - (cast(float)(ch.size.y - ch.bearing.y)) * scale;
		
		w := (cast(float) ch.size.x) * scale;
		h := (cast(float) ch.size.y) * scale;
		
		vertices: [6] Vector4;
		vertices[0] = .{ xpos,     ypos + h,   0.0, 0.0 };            
		vertices[1] = .{ xpos,     ypos,       0.0, 1.0 };
		vertices[2] = .{ xpos + w, ypos,       1.0, 1.0 };
		vertices[3] = .{ xpos,     ypos + h,   0.0, 0.0 };
		vertices[4] = .{ xpos + w, ypos,       1.0, 1.0 };
		vertices[5] = .{ xpos + w, ypos + h,   1.0, 0.0 };
		
		glBindTexture(GL_TEXTURE_2D, ch.texture_id);
        // update content of VBO memory
        glBindBuffer(GL_ARRAY_BUFFER, text_renderer.vbo);
        glBufferSubData(GL_ARRAY_BUFFER, 0, size_of(Vector4) * vertices.count, vertices.data); 
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        // render quad
        glDrawArrays(GL_TRIANGLES, 0, 6);
		
		x += (ch.advance >> 6) * scale;
	}
	
	glBindVertexArray(0);
    glBindTexture(GL_TEXTURE_2D, 0);
}
*/

draw_text :: (text_renderer: *Text_Renderer, text: string, 
			  pos: Vector2, scale: float, color: Vector4,
			  projection: Matrix4, view: Matrix4)
{
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

	gl_set_projection_view_matrix(text_renderer.shader, *projection, *view);
	
	//gl_set_int(text_renderer.shader, "flip", flip);
	gl_set_vector4(text_renderer.shader, "textColor", color);
	glActiveTexture(GL_TEXTURE0);
	glBindVertexArray(text_renderer.vao);
	
	x := pos.x;
	y := pos.y;
	
	for c: 0 .. text.count-1
	{
		if text[c] == xx #char "\n"
		{
			y -= xx text_renderer.font_size * scale;
			x = pos.x;
			continue;
		}
		ch := table_find_pointer(*text_renderer.characters, xx text[c]);
		xpos := x + (cast(float) ch.bearing.x) * scale;
		ypos := y - (cast(float)(ch.size.y - ch.bearing.y)) * scale;
		
		w := (cast(float) ch.size.x) * scale;
		h := (cast(float) ch.size.y) * scale;
		
		vertices: [6] Vector4;
		vertices[0] = Vector4.{ xpos,     ypos + h,   0.0, 0.0 };            
		vertices[1] = Vector4.{ xpos,     ypos,       0.0, 1.0 };
		vertices[2] = Vector4.{ xpos + w, ypos,       1.0, 1.0 };
		vertices[3] = Vector4.{ xpos,     ypos + h,   0.0, 0.0 };
		vertices[4] = Vector4.{ xpos + w, ypos,       1.0, 1.0 };
		vertices[5] = Vector4.{ xpos + w, ypos + h,   1.0, 0.0 };
		
		glBindTexture(GL_TEXTURE_2D, ch.texture_id);
        // update content of VBO memory
        glBindBuffer(GL_ARRAY_BUFFER, text_renderer.vbo);
        glBufferSubData(GL_ARRAY_BUFFER, 0, size_of(Vector4) * vertices.count, vertices.data); 
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        // render quad
        glDrawArrays(GL_TRIANGLES, 0, 6);
		
		x += (ch.advance >> 6) * scale;
	}
	
	glBindVertexArray(0);
    glBindTexture(GL_TEXTURE_2D, 0);
}