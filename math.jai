#import "Math";

Vec2 :: struct($T: Type)
{
    x: T;
    y: T;
}

radians :: (theta: float) -> float
{
	return (theta * (PI/180.0));
}

make_rotation_matrix :: (axis: Vector3, angle: float) -> Matrix4 
{
	q: Quaternion;
	set_from_axis_and_angle(*q, axis.x, axis.y, axis.z, angle);
	return rotation_matrix(Matrix4, q);
}

//NOTE: angle is in radians
make_model_matrix :: (position: Vector3, scale_v: Vector3, axis: Vector3 = .{}, angle: float = 0) -> Matrix4
{
    rotation := identity_of(Matrix4);
	if angle then rotation = make_rotation_matrix(axis, angle);
    
    model := scale(translate(identity_of(Matrix4), .{position.x, position.y, 0}) * rotation, .{scale_v.x, scale_v.y, 0});

    return model;
}