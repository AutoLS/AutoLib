Button_State :: struct
{
	is_down: bool;
	was_down: bool;
	ended_down: bool;
	pressed: bool;
	up: bool;
	half_transitions: s32;
}

Controller_Input :: struct
{
	keys: Table(SDL_Scancode, Button_State);
}

Key_Code :: enum u32 
{
	left :: SDL_SCANCODE_LEFT;
	right :: SDL_SCANCODE_RIGHT;
	up :: SDL_SCANCODE_UP;
	down :: SDL_SCANCODE_DOWN;

	space :: SDL_SCANCODE_SPACE;
	lctrl :: SDL_SCANCODE_LCTRL;

	n :: SDL_SCANCODE_N;
	o :: SDL_SCANCODE_O;
	s :: SDL_SCANCODE_S;
}

Input :: struct
{
	keyboard: Controller_Input;
	keyboard_state: *u8;
	mouse_state: Vec2(s32);
	left_button: Button_State;
	right_button: Button_State;
}

process_keypress :: (new_state: *Button_State, is_down: bool, was_down: bool)
{
	new_state.is_down = is_down;
	new_state.ended_down = is_down;
	new_state.up = was_down;
	new_state.was_down = was_down;
	new_state.half_transitions += 1;
}

reset_controller_input :: (input: *Input)
{
	for *input.keyboard.keys
	{
		it.ended_down = false;
		it.was_down = false;
	}
	input.left_button.ended_down = false;
	input.left_button.was_down= false;
}

get_mouse_position_flipped :: (using input: Input, win_y: s32) -> Vector2
{
	pos := Vector2.{};
	pos.x = xx mouse_state.x;
	pos.y = xx (win_y - mouse_state.y);

	return pos;
}

key_down :: (using input: Input, key: Key_Code) -> bool
{
	button_state := table_find_pointer(*keyboard.keys, xx key);
	if button_state
	{
		return button_state.is_down;
	}
	else
	{
		return false;
	}
}

key_ended_down :: (using input: Input, key: Key_Code) -> bool
{
	button_state := table_find_pointer(*keyboard.keys, xx key);
	if button_state
	{
		return button_state.ended_down;
	}
	else
	{
		return false;
	}
}

button_clicked :: (button: *Button_State) -> bool
{
	return button.ended_down;
}