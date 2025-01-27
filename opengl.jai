#import "stb_image";

COLOR_WHITE :: Vector4.{1, 1, 1, 1};

VERTEX_SOURCE :: #string DONE
#version 330 core

layout (location = 0) in vec3 in_pos;
layout (location = 1) in vec3 in_tex;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

out vec4 debug_color;

void main()
{
    gl_Position = projection * view * model * vec4(in_pos, 1.0);
	debug_color = gl_Position;
}

DONE

FRAGMENT_SOURCE :: #string DONE
#version 330 core

out vec4 out_frag_color;
in vec4 debug_color;

uniform vec4 color;

void main ()
{
    out_frag_color = color;
}
DONE

Simple_Renderer :: struct
{
	shader: u32;
	shape: GL_Shape;
}

create_simple_renderer :: () -> Simple_Renderer
{
	renderer: Simple_Renderer;
	renderer.shader = create_shader(VERTEX_SOURCE, FRAGMENT_SOURCE);
	renderer.shape = make_rect_shape();

	return renderer;
}

TEXTURE_VERTEX_SOURCE :: #string DONE
#version 330 core

layout (location = 0) in vec3 InPos;
layout (location = 1) in vec3 InTexCoords;

out vec3 TexCoords;
out vec3 Vertex;
out vec3 FragPos;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

void main()
{
	FragPos = vec3(model * vec4(InPos, 1.0));
	gl_Position = projection * view * vec4(FragPos, 1.0);
	TexCoords = InTexCoords;
}

DONE

TEXTURE_FRAGMENT_SOURCE :: #string DONE
#version 330 core

out vec4 FragColor;

in vec3 TexCoords;
in vec3 FragPos;

uniform vec4 color;
uniform sampler2D Texture;

void main()
{
	vec4 tex_color = texture(Texture, TexCoords.xy) * color;
	if(tex_color.a < 0.1)
		discard;
	FragColor = tex_color;
}
DONE

compile_shader :: (type: GLenum, source: string) -> u32
{
	shader := glCreateShader(type);
	length: GLint = xx source.count;
	glShaderSource(shader, 1, *source.data, *length);
	glCompileShader(shader);
	
	shader_compile_success: s32;
	info_log: [512] u8;
	
	glGetShaderiv(shader, GL_COMPILE_STATUS, *shader_compile_success);
	if !shader_compile_success
	{
		len := 512;
		glGetShaderInfoLog(shader, xx len, xx *len, info_log.data);
		print("% shader compilation failed: %\n", type, info_log);
	}
	
	return shader;
}

create_shader :: (vertex_source: string, fragment_source: string) -> u32
{
	vertex_shader := compile_shader(GL_VERTEX_SHADER, vertex_source);
	fragment_shader := compile_shader(GL_FRAGMENT_SHADER, fragment_source);
	
	program := glCreateProgram();
	glAttachShader(program, vertex_shader);
	glAttachShader(program, fragment_shader);
	glLinkProgram(program);
	
	linking_success: s32;
	glGetProgramiv(program, GL_LINK_STATUS, *linking_success);
	info_log: [512] u8;
	
	if !linking_success
	{
		len := 512;
		glGetProgramInfoLog(program, xx len, xx *len, info_log.data);
		print("Linking failed: %\n", info_log);
	}
	
	glDeleteShader(vertex_shader);
	glDeleteShader(fragment_shader);  
	
	return program;
}

create_shader :: (path: string) -> u32 {
    
	compile_shader :: (type: GLenum, source: string) -> u32 
	{
		v := glCreateShader(type);

		VERTEX_DEFINE :: "#define VERTEX_SHADER\n";
		FRAGMENT_DEFINE :: "#define FRAGMENT_SHADER\n";

		sources : [3] *u8;
		lengths : [3] GLint;

		sources[0] = "#version 330 core\n";
		lengths[0] = xx strlen(sources[0]);

		if type == GL_VERTEX_SHADER
		{
			sources[1] = VERTEX_DEFINE.data;
			lengths[1] = xx strlen(VERTEX_DEFINE.data);
		}
		else if type == GL_FRAGMENT_SHADER
		{
			sources[1] = FRAGMENT_DEFINE.data;
			lengths[1] = xx strlen(FRAGMENT_DEFINE.data);
		}
		else
		{
			assert(false);
		}

		a := to_c_string(source);
		defer free(a);

		sources[2] = a;
		lengths[2] = xx strlen(a);

		glShaderSource(v, 3, xx sources.data, lengths.data);
		glCompileShader(v);

		status: GLint;
		glGetShaderiv(v, GL_COMPILE_STATUS, *status);
		if (status == 0) {
			len: GLint;
			glGetShaderiv(v, GL_INFO_LOG_LENGTH, *len);
			buf := cast(*u8) alloc(len);
			glGetShaderInfoLog(v, xx len, xx *len, buf);
			print("ERROR: %\n", to_string(buf));
			free(buf);

			glDeleteShader(v);
			return 0;
		}

		return v;
	}
	
	source, success := read_entire_file(path);
	
	if success
	{
		vert := compile_shader(GL_VERTEX_SHADER, source);
		frag := compile_shader(GL_FRAGMENT_SHADER, source);

		program := glCreateProgram();

		glAttachShader(program, vert);
		glAttachShader(program, frag);

		glLinkProgram(program);

		status: GLint;
		glGetProgramiv(program, GL_LINK_STATUS, *status);
		if (status == 0) {
			len: GLint;
			glGetProgramiv(program, GL_INFO_LOG_LENGTH, *len);
			buf := cast(*u8) alloc(len);
			glGetProgramInfoLog(program, xx len, xx *len, buf);
			print("ERROR: %\n", to_string(buf));
			free(buf);

			glDeleteProgram(program);
			glDeleteShader(vert);
			glDeleteShader(frag);
			return 0;
		}

		glDetachShader(program, vert);
		glDetachShader(program, frag);

		glValidateProgram(program);
		return program;
	}
	else
	{
		print("Reading file failed!\n");
		return 0;
	}
}

GL_Shape :: struct
{
	vao, vbo: u32;
	vertices: [..] Vector3;

	n_vertices, n_vertices_size: u32;
	usage: GLenum = GL_STATIC_DRAW;
	type: GLenum;
}

make_rect_shape :: () -> GL_Shape
{
	rect: GL_Shape;
	rect.type = GL_TRIANGLES;
    array_add(*rect.vertices, Vector3.{0.5, 0.5, 0});   //Top Right		
    array_add(*rect.vertices, Vector3.{0.5, -0.5, 0});  //Bottom Right
    array_add(*rect.vertices, Vector3.{-0.5, -0.5, 0}); //Bottom Left
    array_add(*rect.vertices, Vector3.{-0.5, -0.5, 0}); //Bottom Left
    array_add(*rect.vertices, Vector3.{-0.5, 0.5, 0});  //Top Left
    array_add(*rect.vertices, Vector3.{0.5, 0.5, 0});   //Top Right	

	gl_gen_shape(*rect);
	gl_upload_shape_data(*rect);
	gl_set_attrib_pointer(*rect, 0, 3, 0, 0);

	return rect;
}

make_triangle_shape :: () -> GL_Shape
{
	s: GL_Shape;
	s.type = GL_TRIANGLES;
	array_add(*s.vertices, Vector3.{0, 0.5, 0});   
    array_add(*s.vertices, Vector3.{-0.5, -0.5, 0});  
    array_add(*s.vertices, Vector3.{0.5, -0.5, 0}); 

	gl_gen_shape(*s);
	gl_upload_shape_data(*s);
	gl_set_attrib_pointer(*s, 0, 3, 0, 0);

	return s;
}

make_right_triangle_shape :: (flip: Flip_Operation = .Flip_None) -> GL_Shape
{
	s: GL_Shape;
	s.type = GL_TRIANGLES;
	array_add(*s.vertices, Vector3.{-0.5, 0.5, 0});   
    array_add(*s.vertices, Vector3.{-0.5, -0.5, 0});  
    array_add(*s.vertices, Vector3.{0.5, -0.5, 0}); 

	if flip == 
    {
        case .Flip_Horizontal;
        {
            for *v : s.vertices v.x = -v.x;
        }
        case .Flip_Vertical;
        {
            for *v : s.vertices v.y = -v.y;
        }
    }

	gl_gen_shape(*s);
	gl_upload_shape_data(*s);
	gl_set_attrib_pointer(*s, 0, 3, 0, 0);

	return s;
}

gl_gen_shape :: (shape: *GL_Shape)
{
	glGenVertexArrays(1, *shape.vao);
	glGenBuffers(1, *shape.vbo);

	shape.n_vertices = xx shape.vertices.count;
	shape.n_vertices_size = size_of(Vector3) * shape.n_vertices; 
	print("Vector3 size: %, total size: %\n", size_of(Vector3), shape.n_vertices_size);
}

gl_upload_shape_data :: (shape: *GL_Shape)
{
	glBindVertexArray(shape.vao);

	glBindBuffer(GL_ARRAY_BUFFER, shape.vbo);
	glBufferData(GL_ARRAY_BUFFER, shape.n_vertices_size, shape.vertices.data, shape.usage);

	glBindVertexArray(0);
}

gl_set_attrib_pointer :: (shape: *GL_Shape, loc: u32, size: s32, stride: GLsizei, offset: s32)
{
	glBindVertexArray(shape.vao);
	glVertexAttribPointer(loc, size, GL_FLOAT, GL_FALSE, stride * size_of(float), xx (size_of(float)*offset));
	glEnableVertexAttribArray(loc);
	glBindVertexArray(0);
}

gl_load_texture :: (path: *u8, alpha: bool, flip: bool = false, n: s32 = 0) -> u32
{
	//TODO: Find a way to flip the image? Either implement yourself or do it in shader.
	//stbi_set_flip_vertically_on_load(flip);
	texture_id: u32;
	glGenTextures(1, *texture_id);
	
	width, height, components: s32;
	data := stbi_load(path, *width, *height, *components, n);
	if data
	{
		format: GLenum;
		if components == 1
            format = GL_RED;
		else if components == 3
            format = GL_RGB;
        else if components == 4
            format = GL_RGBA;
			
		glBindTexture(GL_TEXTURE_2D, texture_id);
        glTexImage2D(GL_TEXTURE_2D, 0, xx format, xx width, xx height, 0, format, GL_UNSIGNED_BYTE, data);
        glGenerateMipmap(GL_TEXTURE_2D);
        
		if(alpha)
		{
			glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
			glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		}
		else
		{
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
		}
		
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        stbi_image_free(data);
	}
	else
	{
		print("ERROR: cannot load texture!\n");
		stbi_image_free(data);
	}
	
	return texture_id;
}

gl_set_projection_view_matrix :: (shader: u32, projection: *Matrix4, view: *Matrix4)
{
	glUseProgram(shader);
	proj_loc := glGetUniformLocation(shader, "projection");
	view_loc := glGetUniformLocation(shader, "view");
	glUniformMatrix4fv(proj_loc, 1, true, xx projection);
	glUniformMatrix4fv(view_loc, 1, true, xx view);
	glUseProgram(0);
}

gl_set_vector4 :: (shader: u32, location: *u8, entry: Vector4)
{
	glUseProgram(shader);
	glUniform4f(glGetUniformLocation(shader, location), entry.x, entry.y, entry.z, entry.w);
}

gl_draw :: (shape: *GL_Shape, shader: u32, model: *Matrix4, color: Vector4)
{
	glUseProgram(shader);
	color_loc := glGetUniformLocation(shader, "color");
	//print("color_loc: %\n", color_loc);
	glUniform4f(color_loc, color.x, color.y, color.z, color.w);

	model_loc := glGetUniformLocation(shader, "model");
	//print("Model_loc: %\n", model_loc);
	glUniformMatrix4fv(model_loc, 1, true, xx model);

	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

	glBindVertexArray(shape.vao);
	glDrawArrays(shape.type, 0, shape.n_vertices);
	
	glDisable(GL_BLEND);
	glBindVertexArray(0);
	glUseProgram(0);
}