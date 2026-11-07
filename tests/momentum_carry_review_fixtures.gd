extends RefCounted
## p / original contact fixtures and exact open-loop inputs from the independent review.

func corridor(w: Node3D, s: Object, angle: float, clearance: float, wall: bool, signx: float) -> void:
	var a := deg_to_rad(angle)
	s.ramp(w,"floor",Vector3(0,40,10),Vector3(0,40-120*tan(a),-110),8)
	if clearance > 0:
		s.ramp(w,"ceiling",Vector3(0,40+clearance+1.0/cos(a),10),Vector3(0,40-120*tan(a)+clearance+1.0/cos(a),-110),8)
	if wall:
		s.box(w,"rail",Vector3(2*signx,0,-30),Vector3(0.5,200,200))

func ledge(w: Node3D, s: Object) -> void:
	s.box(w,"ledge",Vector3(0,-0.5,-20),Vector3(2,1,80))
	s.box(w,"catch",Vector3(0,-5.5,-20),Vector3(80,1,120))

func vee(w: Node3D, s: Object, roll: float) -> void:
	for signx: float in [-1.0,1.0]:
		var a := deg_to_rad(roll)*signx
		var body: StaticBody3D = s.box(w,"slope_%d" % signx,Vector3(signx*5*cos(a),5*abs(sin(a))-0.5/cos(a),-20),Vector3(10,1,120))
		body.rotation.z = a

func approach(w: Node3D, s: Object, signx: float) -> void:
	s.box(w,"top",Vector3(0,11.5,0),Vector3(20,1,10))
	s.ramp(w,"descent",Vector3(0,12,-5),Vector3(0,0,-25.78460969),20)
	s.box(w,"launch",Vector3(0,-0.5,-30.78460969),Vector3(20,1,10))
	s.box(w,"target",Vector3(3*signx,-0.5,-60),Vector3(4,1,32.43078062))
	s.box(w,"catch",Vector3(0,-5.5,-60),Vector3(80,1,180))

func cases(s: Object) -> Array:
	var out: Array = []
	for profile: String in ["broad","narrow"]:
		for signx: float in [1.0,-1.0]:
			var hand := "right" if signx>0 else "left"
			for repeat: int in 3:
				var min_name := "minimal_%s_%s_%d" % [profile,hand,repeat]
				out.append({"name":min_name,"build":corridor.bind(s,30.0,0.0,true,signx),"pose":s.yaw_pose(Vector3(1.45108294487*signx,3.4847629070282,-53.3626708984375),-0.12*signx),"seed":Vector3(0,-20.0365810394287,-22.3228416442871),"profile":profile,"ticks":3,"contacts":true,"tape":[[0,"w",true],[0,"space",true]],"separating_support_gate":true,"contact_diagnostic":true,"same_as":"minimal_%s_%s_0" % [profile,hand]})
			for repeat: int in 2:
				out.append({"name":"earned_rail_%s_%s_%d" % [profile,hand,repeat],"build":corridor.bind(s,30.0,0.0,true,signx),"pose":s.yaw_pose(Vector3(0,40-10*tan(deg_to_rad(30.0))+0.15,0),-0.12*signx),"profile":profile,"ticks":500,"contacts":true,"tape":[[0,"w",true],[300,"space",true]],"separating_support_gate":true,"contact_diagnostic":true,"same_as":"earned_rail_%s_%s_0" % [profile,hand]})
			for control: String in ["no_rail","no_w","buffer_tap","observation"]:
				var tape := [[0,"space",true]]
				if control != "no_w":
					tape.append([0,"w",true])
				if control == "buffer_tap":
					tape.append([2,"space",false])
				var cfg := {"name":"control_%s_%s_%s" % [profile,hand,control],"build":corridor.bind(s,30.0,0.0,control!="no_rail",signx),"pose":s.yaw_pose(Vector3(1.45108294487*signx,3.4847629070282,-53.3626708984375),-0.12*signx),"seed":Vector3(0,-20.0365810394287,-22.3228416442871),"profile":profile,"ticks":3,"contacts":true,"tape":tape,"separating_support_gate":control in ["no_rail","no_w","buffer_tap"],"extra_reports":control=="observation"}
				if control == "observation":
					cfg.same_as="minimal_%s_%s_0" % [profile,hand]
				out.append(cfg)
			for scenario: String in ["straight","preaim","late_side","wobble","countersteer","brake","early","late"]:
				var jump_at := 330
				if scenario == "early":
					jump_at=322
				if scenario == "late":
					jump_at=338
				var tape := [[0,"w",true],[jump_at,"space",true],[jump_at+3,"space",false]]
				if scenario in ["preaim","early","late","wobble"]:
					tape.append(["smooth",240,40,70.0*signx])
				if scenario == "late_side":
					var key := "d" if signx>0 else "a"
					tape.append([335,key,true])
					tape.append([365,key,false])
					tape.append(["smooth",335,20,60.0*signx])
				if scenario == "wobble":
					tape.append(["sine",290,80,8.0*signx,24])
				if scenario == "countersteer":
					tape.append(["smooth",240,40,150.0*signx])
					tape.append(["smooth",290,35,-100.0*signx])
				if scenario == "brake":
					tape.append([300,"w",false])
					tape.append([300,"s",true])
					tape.append([330,"s",false])
					tape.append([331,"w",true])
				out.append({"name":"approach_%s_%s_%s" % [profile,hand,scenario],"build":approach.bind(s,signx),"pose":s.yaw_pose(Vector3(0,12.02,0),0),"profile":profile,"ticks":570,"contacts":true,"tape":tape})
	for signx: float in [1.0,-1.0]:
		var hand := "right" if signx>0 else "left"
		for angle: float in [20.0,40.0]:
			out.append({"name":"ceiling_%d_%s" % [angle,hand],"build":corridor.bind(s,angle,2.3,true,signx),"pose":s.yaw_pose(Vector3(0,40-10*tan(deg_to_rad(angle))+0.08,0),-0.12*signx),"seed":s.along(-0.12*signx,20),"ticks":250,"contacts":true,"tape":[[0,"w",true],[40,"space",true]],"contact_diagnostic":true})
		for x: float in [0.85,1.15,1.29]:
			for y: float in [-0.5,0.1,2.0]:
				out.append({"name":"ledge_%s_%.2f_%.1f" % [hand,x,y],"build":ledge.bind(s),"pose":s.yaw_pose(Vector3(x*signx,y,0),-0.1*signx),"seed":s.along(-0.1*signx,12,-2),"ticks":180,"contacts":true,"tape":[[0,"w",true],[0,"space",true]]})
		for roll: float in [10.0,25.0,40.0]:
			out.append({"name":"vee_%s_%d" % [hand,roll],"build":vee.bind(s,roll),"pose":s.yaw_pose(Vector3(0,1,0),0.2*signx),"seed":s.along(0.2*signx,18,-4),"ticks":360,"contacts":true,"tape":[[0,"w",true],[80,"space",true]]})
	return out
