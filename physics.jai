
physics_current_time: float = 0;
physics_time_accumlator: float = 0;
physics_dt: float = 1.0 / 120.0;

physics_gravity: Vector3 = .{0, -980, 0};
physics_damping_factor: float = 0.95;

set_damping_factor :: (x: float)
{
    physics_damping_factor = x;
}

Sim_World :: struct
{
    bodies: [..] Rigid_Body;
    collision_resolutions: [..] Resolution;
}

generate_random_body :: (world: *Sim_World)
{
    x := random_get_within_range(100, 1000);
    y := random_get_within_range(500, 700);
    s := random_get_within_range(30, 50);
    mass: float = s / 5;

    r: float = xx random_get_zero_to_one_open_new();
    g: float = xx random_get_zero_to_one_open_new();
    b: float = xx random_get_zero_to_one_open_new();

    body_index := add_body(world, .{x, y, 0}, .{}, .{s, s, 0}, mass);
    body := *world.bodies[body_index];
    body.color = .{r, g, b, 1};
    body.restitution = 0;
}

add_body :: (using world: *Sim_World, p: Vector3, v: Vector3, s: Vector3, mass: float = 10) -> int
{
    body := make_rigid_body(p, v, s, mass);
    array_add(*bodies, body);

    return bodies.count-1;
}

add_wall :: (using world: *Sim_World, p: Vector3, s: Vector3, friction: float = 0.5) -> int
{
    body := make_rigid_body(p, .{}, s, 0);
    body.freeze_orientation = true;
    body.friction = friction;

    array_add(*bodies, body);
    return bodies.count-1;
}

add_slope :: (using world: *Sim_World, p: Vector3, s: Vector3, friction: float = 0.5) -> int 
{
    body := make_rigid_body(p, .{}, s, 0, .Right_Triangle);
    body.freeze_orientation = true;
    body.friction = friction;

    array_add(*bodies, body);
    return bodies.count-1;
}

get_body :: (world: *Sim_World, index: int) -> *Rigid_Body
{
    return *world.bodies[index];
}

clear_force_applied :: (using world: *Sim_World)
{
    for *body : bodies
    {
        body.force = .{};
        body.torque = .{};
    }
}

simulate_world :: (using world: *Sim_World)
{
    array_reset(*collision_resolutions);

    for i : 0 .. bodies.count-1
    {
        for j : i+1 .. bodies.count-1
        {
            a := *bodies[i];
            b := *bodies[j];
            resolution: Resolution;
            resolution.cp.allocator = temp;
            resolution.contacts.allocator = temp;
            resolution.body_a = a;
            resolution.body_b = b;
            if test_SAT(a.shape, b.shape, *resolution)
            {
                //a.color = .{1, 0, 0, 1};
                //b.color = .{1, 0, 0, 1};
                array_add(*collision_resolutions, resolution);
                //print("overlap: %\n", resolution.depth);
                // for resolution.cp
                // {
                //     print("cp:% \n", it);
                // }
            }
        }
    }

    new_time := get_current_time_in_seconds();
    frame_time := new_time - physics_current_time;
    physics_current_time = new_time;

    physics_time_accumlator += frame_time;

    while physics_time_accumlator >= physics_dt
    {
        for *body : bodies
        {
            // for body.shape.global_vertices
            // {
            //     apply_force(body, physics_gravity, it);
            // }
            apply_force(body, physics_gravity, body.position);
            integrate_for_velocity(body, physics_dt);
        }
        
        for collision_resolutions
        {
            for c : it.contacts
            {
                //update_contact(*it, *c);
                resolve_contact(*it, *c);
            }
        }

        for bodies
        {
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

    color: Vector4 = .{1, 1, 1, 1};
}

make_rigid_body :: (p: Vector3, v: Vector3, s: Vector3, mass: float, body_type: Polygon = .Rect) -> Rigid_Body
{
    body: Rigid_Body;
    body.position = p;
    body.velocity = v;
    body.orientation = Quaternion.{0, 0, 0, 1};
    body.inverse_mass = ifx mass > 0 then 1.0/mass else 0;

    if body_type ==
    {
        case .Rect; body.shape = make_rect(p, s);
        case .Right_Triangle; body.shape = make_right_triangle(p, s);
    }
    
    if mass > 0
    {
        one_twelve := 1.0 / 12.0;
        x_x := s.x * s.x;
        y_y := s.y * s.y;

        //?: I will probably just use this for all types of shapes idk
        inertia_tensor: Matrix3;
        inertia_tensor._11 = one_twelve * mass * y_y;
        inertia_tensor._22 = one_twelve * mass * x_x;
        inertia_tensor._33 = one_twelve * mass * (x_x + y_y);

        body.inverse_inertia = inverse(inertia_tensor);
    }

    return body;
}

apply_force :: (body: *Rigid_Body, f: Vector3, at: Vector3)
{
    body.force += f;
    body.torque += cross(at - body.position, f);
}

integrate_for_velocity :: (body: *Rigid_Body, dt: float)
{
    //if body.inverse_mass > 0 then body.velocity += physics_gravity * dt;

    if body.inverse_mass > 0
    {
        body.velocity += body.force * body.inverse_mass*dt;
        body.velocity.x = body.velocity.x * physics_damping_factor;
    }

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
        body.orientation = body.orientation + (Quaternion.{av.x, av.y, av.z, 0} * body.orientation);
    }
    
    update_shape(*body.shape, body.position, body.shape.scale, body.orientation);
    body.orientation = normalize(body.orientation);
}

update_contact :: (using resolution: *Resolution, c: *Contact)
{
    c.sum_impulse_contact = 0;
    c.sum_impulse_friction = .{};
    c.b = 0;

    baumgrate_scalar := 0.1;
    baumgrate_slop := 0.001;
    penetration_slop := min(c.depth + baumgrate_slop, 0);

    c.b += -(baumgrate_scalar / physics_dt) * penetration_slop;

    elasticity := body_a.restitution * body_b.restitution;
    elasticity_term := dot(c.normal, body_a.velocity + 
                        cross(c.rel_pos_a, body_a.angular_velocity) - body_b.velocity - cross(c.rel_pos_b, body_b.angular_velocity));

    c.b += (elasticity * elasticity_term) / contacts.count;
}

resolve_contact :: (using resolution: *Resolution, c: *Contact)
{
    r1 := c.rel_pos_a;
    r2 := c.rel_pos_b;

/*  NOTE: Resolution
    JV + b = 0
    C: (Pb - Pa) . n >= 0
    C': (-va - wa x ra + vb + wb x rb) . n >= 0
    where J = [-n r1xn n -r2xn]
    lambda = -(JV + b) * EffectiveMass
    EffectiveMass = (J*Minv*JT)
*/

    j1: Vector3 = ifx body_a.inverse_mass == 0 then .{} else -c.normal;
    j2: Vector3 = ifx body_a.inverse_mass == 0 then .{} else cross(r1, c.normal);
    j3: Vector3 = ifx body_b.inverse_mass == 0 then .{} else c.normal;
    j4: Vector3 = ifx body_b.inverse_mass == 0 then .{} else -cross(r2, c.normal);
    
    k: float = body_a.inverse_mass + dot(j2, body_a.inverse_inertia * j2) +
              body_b.inverse_mass + dot(j4, body_b.inverse_inertia * j4);

    if(k != 0)
    {
        effective_mass: float = 1.0 / k;

        jv: float = dot(j1, body_a.velocity) +
                    dot(j2, body_a.angular_velocity) +
                    dot(j3, body_b.velocity) +
                    dot(j4, body_b.angular_velocity);

        beta: float = 0.3;
        restitution: float = body_a.restitution * body_b.restitution;
        rel_vel := -body_a.velocity - cross(body_a.angular_velocity, r1) +
                           body_b.velocity + cross(body_b.angular_velocity, r2);
        
        closing_vel: float = dot(rel_vel, c.normal);
        b: float = -(beta / physics_dt) * c.depth + restitution * closing_vel;
        
        lambda: float = effective_mass * (-(jv + b));
        lambda = max(lambda, 0);

        body_a.velocity += body_a.inverse_mass * j1 * lambda;
        body_b.velocity += body_b.inverse_mass * j3 * lambda;

        body_a.angular_velocity += body_a.inverse_inertia * j2 * lambda;
        body_b.angular_velocity += body_b.inverse_inertia * j4 * lambda;

        va := body_a.velocity + cross(body_a.angular_velocity, r1);
        vb := body_b.velocity + cross(body_b.angular_velocity, r2);

        vab := vb - va;
        tangent := vab - c.normal * dot(vab, c.normal);
        tangent_length: float = length(tangent);

        if(tangent_length > 0.000001)
        {
            tangent = tangent / tangent_length;
            d: float = dot(tangent, cross(body_a.inverse_inertia * cross(r1, tangent), r1) + cross(body_b.inverse_inertia * cross(r2, tangent), r2));

            friction_mass: float = body_a.inverse_mass + body_b.inverse_mass + d;

            if(friction_mass > 0)
            {
                friction_coeff: float = body_a.friction * body_b.friction;
                jt: float = -dot(vab, tangent) * friction_coeff;
                jt = jt / friction_mass;

                body_a.velocity -= tangent * (jt * body_a.inverse_mass);
                body_b.velocity += tangent * (jt * body_b.inverse_mass);

                body_a.angular_velocity += body_a.inverse_inertia * cross(r1, tangent * jt);
                body_b.angular_velocity -= body_b.inverse_inertia * cross(r2, tangent * jt);
            }                      
        }
    }
}