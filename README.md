# My custom made library (WIP)

## Current features: 
- Creating window using SDL
- OpenGL rendering
- ImGui support
- 2D Constraint-based physics

Example usage (Drawing a triangle using openGL)
```c
#import "Basic";
#import "Math";
#import "AutoLib";

main :: ()
{
    app: Application;
    app.name = "Hello Triangle";
    app.w = 1280;
    app.h = 720;
    app.clear_color = .{0, 0, 0, 1.0};

    init_lib(*app);

    shader := create_shader(VERTEX_SOURCE, FRAGMENT_SOURCE);

    tri := make_triangle_shape();

    while app.running
    {
        reset_temporary_storage();

        handle_events(*app);

        clear_window(*app);

        //Logic
        if app.is_quit
        {
            app.running = false;
        }

        //Lock the framerate to 60
        lock_fps(*app.clock, 60);

        //Render
        projection := orthographic_projection_matrix(0, 1280, 0, 720, -1, 1);
        view := identity_of(Matrix4);
        gl_set_projection_view_matrix(shader, *projection, *view);

        //Draws a red triangle in the center
        model := make_model_matrix(.{640, 360, 0}, .{100, 100});
        gl_draw(*tri, shader, *model, .{1, 0, 0, 1});

        draw_frame(*app);

        update_clock(*app.clock);
    }
}
```

Example physics demo: https://streamable.com/knv301
