using Sound :: #import "Sound_Player";

User_Sound :: struct 
{
    data: Sound_Data;
    category: Sound_Category;
}

Play_Sound_Settings :: struct
{
    repeat: bool = false;
    volume: float = 1.0;
    rate: float = 1.0;
}

Sound_Player :: struct
{
    sound_table: Table(string, User_Sound);
}

add_to_sound_player :: (using sound_player: *Sound_Player, name: string, path: string, category := Sound_Category.GENERAL_SFX)
{
    sound: User_Sound;
    sound.data = load_audio_file(path);
    sound.category = category;
    table_add(*sound_table, name, sound);
}

set_volume :: (value: float) //NOTE: Value is 0 to 1, all sounds are multiplied by this value
{
    set_master_volume(value);
}

play_sound :: (using sound_player: *Sound_Player, name: string, settings: Play_Sound_Settings = .{})
{
    sound := table_find_pointer(*sound_table, name);
    if sound
    {
        stream := make_stream(*sound.data, sound.category);
        stream.user_volume_scale = settings.volume;
        stream.rate_scale = settings.rate;
        set_repeating(stream, settings.repeat);
        start_playing(stream);
    }
}

stop_sound :: (using sound_player: *Sound_Player, name: string)
{
    sound := table_find_pointer(*sound_table, name);
    if sound
    {
        stop_stream_abruptly(*sound.data);
    }
}

stop_all_sounds :: (using sound_player: *Sound_Player)
{
    for sound_table
    {
        stop_stream_abruptly(*it.data);
    }
}

update_sound_player :: ()
{
    Sound.update();
}

close_sound_player :: ()
{
    sound_player_shutdown();
}