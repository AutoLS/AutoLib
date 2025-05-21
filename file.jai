File_Handler :: struct
{
    begin_new_file: bool;
    begin_open_file: bool;
    begin_save_file: bool;
}

handle_file_action :: (using app: *Application, is_new_file: bool, is_open_file: bool, is_save_file: bool)
{
    using app.file_handler;
    begin_new_file = false;
    begin_open_file = false;
    begin_save_file = false;

    new_file_shortcut := key_down(input, .lctrl) && key_ended_down(input, .n);
    open_file_shortcut := key_down(input, .lctrl) && key_ended_down(input, .o);
    save_file_shortcut := key_down(input, .lctrl) && key_ended_down(input, .s);

    if is_new_file || new_file_shortcut 
    {
        begin_new_file = true;
    }

    if is_open_file || open_file_shortcut 
    {
        begin_open_file = true;
    }

    if is_save_file || save_file_shortcut 
    {
        begin_save_file = true;
    }
}