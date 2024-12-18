
physics_current_time: float = 0;
physics_time_accumlator: float = 0;
physics_dt: float = 1.0 / 120.0;

physics_gravity: Vector3 = .{0, -98, 0};
physics_damping_factor: float = 0.95;

set_damping_factor :: (x: float)
{
    physics_damping_factor = x;
}

Sim_World :: struct
{
    bodies: [..] Rigid_Body;
}

add_body :: (using world: *Sim_World, p: Vector3, v: Vector3, s: Vector3, mass: float = 10) -> *Rigid_Body
{
    body := make_rigid_body(p, v, s, mass);
    array_add(*bodies, body);

    return *bodies[bodies.count-1];
}

simulate_world :: (using world: *Sim_World)
{
    new_time := get_current_time_in_seconds();
    frame_time := new_time - physics_current_time;
    physics_current_time = new_time;

    physics_time_accumlator += frame_time;

    while physics_time_accumlator >= physics_dt
    {
        for bodies
        {
            integrate_for_velocity(*it, physics_dt);
            integrate_for_position(*it, physics_dt);
        }

        physics_time_accumlator -= physics_dt;
    }
}

Rigid_Body :: struct
{
    shape: Shape;

    position: Vector3;
    velocity: Vector3;
    force: Vector3;

    inverse_mass: float;

    orientation: Quaternion;
    angular_velocity: Vector3;
    torque: Vector3;
    inverse_inertia: Matrix3;

    restitution: float;
    friction: float;

    freeze_orientation: bool;
}

make_rigid_body :: (p: Vector3, v: Vector3, s: Vector3, mass: float) -> Rigid_Body
{
    body: Rigid_Body;
    body.position = p;
    body.velocity = v;
    body.orientation = Quaternion.{0, 0, 0, 1};
    body.inverse_mass = ifx mass > 0 then 1.0/mass else 0;

    body.shape = make_rect(p, s);
    
    if mass > 0
    {
        one_twelve := 1.0 / 12.0;
        x_x := s.x * s.x;
        y_y := s.y * s.y;

        inertia_tensor: Matrix3;
        inertia_tensor._11 = one_twelve * mass * y_y;
        inertia_tensor._22 = one_twelve * mass * x_x;
        inertia_tensor._33 = one_twelve * mass * (x_x + y_y);

        body.inverse_inertia = inverse(inertia_tensor);
    }

    return body;
}

integrate_for_velocity :: (body: *Rigid_Body, dt: float)
{
    if body.inverse_mass > 0 then body.velocity += physics_gravity * dt;

    body.velocity += body.force * body.inverse_mass*dt;
    body.velocity.x = body.velocity.x * physics_damping_factor;

    if !body.freeze_orientation
    {
        body.angular_velocity += body.inverse_inertia * body.torque * dt;
        body.angular_velocity = body.angular_velocity * physics_damping_factor;
    }
}

integrate_for_position :: (body: *Rigid_Body, dt: float)
{
    body.position += body.velocity * dt;
    
    if(!body.freeze_orientation)
    {
        av := body.angular_velocity * dt * 0.5;
        body.orientation = body.orientation + Quaternion.{av.x, av.y, av.z, 0} * body.orientation;
    }
    
    update_shape(*body.shape, body.position, body.shape.scale, body.orientation);
    normalize_or_identity(*body.orientation);
}