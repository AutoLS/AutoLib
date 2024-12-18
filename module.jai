#import "String";
#import "Windows";
#import "System";
#import "Deep_Copy";
#import "Hash_Table";
#import "Math";
#import "Reflection";
#import "JSON";
JSON :: #import "JSON_Plus";
#load "math.jai";
#load "input.jai";
#load "ui.jai";
#load "time.jai";
#load "opengl.jai";
#load "geometry.jai";
#load "physics.jai";
#load "application.jai";

init_lib :: (using application: *Application)
{
    SDL_Init(SDL_INIT_VIDEO);

    window = SDL_CreateWindow
    (
        to_c_string(name), 
        SDL_WINDOWPOS_CENTERED,
		SDL_WINDOWPOS_CENTERED, 
		w, h,
		SDL_WINDOW_OPENGL
    );

    if window == null 
	{
		print("Could not create window: %\n", to_string(SDL_GetError()));
		return;
	}

	SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, xx SDL_GL_CONTEXT_PROFILE_CORE);
	gl_context := SDL_GL_CreateContext(window);
    if !gl_context 
	{
        print( "Could not create OpenGL context: %\n", to_string(SDL_GetError()));
        return;
    }

	gl_load(*gl, SDL_GL_GetProcAddress);

    imgui_context = ImGui.CreateContext();

    ImGui_ImplSdl_Init(window);

    ImGui.StyleColorsClassic();

    imgui_io = ImGui.GetIO();

    clock = init_clock();
}