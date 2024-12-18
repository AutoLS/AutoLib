
Application :: struct
{
    running: bool = true;
    is_quit: bool;

    input: Input;
    clock: Clock;

    window: *SDL_Window;
    name: string;
    w, h: s32;

    imgui_context: *ImGui.ImGuiContext;
    imgui_io: *ImGui.IO;

    clear_color: Vector4 = .{0, 0, 0, 1.0};
}

handle_events :: (using app: *Application)
{
    reset_controller_input(*input);

    event: SDL_Event;
    while SDL_PollEvent(*event) 
    {
        ImGui_ImplSdl_ProcessEvent(*event);
        if event.type == SDL_QUIT   is_quit = true;
        if event.type == SDL_WINDOWEVENT && 
            event.window.event == SDL_WINDOWEVENT_CLOSE && 
            event.window.windowID == SDL_GetWindowID(window) 
        {
            is_quit = true;
        }

        if event.type ==
        {
            case SDL_KEYDOWN; #through;
            case SDL_KEYUP;
            {
                is_down: bool = event.key.state == SDL_PRESSED;
                was_down: bool;
                
                if event.key.state == SDL_RELEASED
                {
                    was_down = true;
                }
                else if event.key.repeat != 0
                {
                    was_down = true;
                }
                
                if event.key.repeat == 0
                {
                    key := event.key.keysym.scancode;
                    
                    button_state := table_find_pointer(*input.keyboard.keys, key);
                    if button_state 
                    {
                        process_keypress(button_state, is_down, was_down);
                    }
                    else
                    {
                        new_state: Button_State;
                        process_keypress(*new_state, is_down, was_down);
                        table_add(*input.keyboard.keys, key, new_state);
                    }
                }
            }
            case SDL_MOUSEMOTION;
            {
                SDL_GetMouseState(*input.mouse_state.x, *input.mouse_state.y);
            }
            case SDL_MOUSEBUTTONDOWN; #through;
            case SDL_MOUSEBUTTONUP;
            {
                is_down: bool = event.button.state == SDL_PRESSED;
                was_down: bool;
                
                if event.button.state == SDL_RELEASED
                {
                    was_down = true;
                }
                
                if event.button.button == SDL_BUTTON_LEFT
                {
                    process_keypress(*input.left_button, is_down, was_down);
                }
            }
        }
    }
}

clear_window :: (using app: *Application)
{
    ImGui_ImplSdl_NewFrame(window);
    ImGui.NewFrame();

    // w = xx imgui_io.DisplaySize.x; 
    // h = xx imgui_io.DisplaySize.y;  

    glViewport(0, 0, xx w, xx h);
    glClearColor(clear_color.x, clear_color.y, clear_color.z, clear_color.w);
    glClear(GL_COLOR_BUFFER_BIT);
}

draw_frame :: (using app: *Application)
{
    ImGui.Render();
    ImGui_ImplSdl_RenderDrawLists(ImGui.GetDrawData());
    SDL_GL_SwapWindow(window);
}