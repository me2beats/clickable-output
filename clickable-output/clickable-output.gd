tool
extends EditorPlugin


var v_offset: = 4

func _enter_tree():
	var base  = get_editor_interface().get_base_control()

	var output:RichTextLabel = get_output(base)
	Engine.set_meta('output', output)
	
	var output_parent = output.get_parent()
	output_parent.remove_child(output)
	
	var output_scroll_box:HBoxContainer

	if Engine.has_meta('output_scroll_box'):
		output_scroll_box = Engine.get_meta('output_scroll_box')
	else:
		output_scroll_box = preload("OutputScrollBox.tscn").instance()
		Engine.set_meta('output_scroll_box', output_scroll_box)
	
	var output_vscroll:VScrollBar = output.get_child(0)
	Engine.set_meta('output_vscroll', output_vscroll)
	
	set_parent(output_vscroll, output_scroll_box)
	set_parent(output, output_scroll_box.get_node("ScrollContainer"))


	output.rect_min_size.x = 10000
	output_parent.add_child(output_scroll_box)
	
	output.connect("gui_input", self, "on_output_input", [output])





func _exit_tree():
	var output_scroll_box:BoxContainer = Engine.get_meta('output_scroll_box')
	var output:RichTextLabel = Engine.get_meta('output')
	var output_vscroll:VScrollBar = Engine.get_meta('output_vscroll')

	output.rect_min_size.x = 0

	var output_parent = output_scroll_box.get_parent()

	set_parent(output_vscroll, output)
	set_parent(output, output_parent)
	output_parent.remove_child(output_scroll_box)

	output.disconnect("gui_input", self, "on_output_input") # is this needed?
	

var recent_pressed_position = Vector2.ZERO

func on_output_input(event:InputEvent, output:RichTextLabel):
	event = event as InputEventMouseButton
	if not (
		event
		and event.button_index == BUTTON_LEFT
	) : return

	if event.pressed:
		recent_pressed_position = event.position
		return

	if !event.position == recent_pressed_position: return

	yield(get_tree(), "idle_frame")


	var line_idx: = get_line_idx_by_y(output, event.position.y-v_offset)
	if line_idx == -1: return
	


	var line:String = get_line_by_idx(output, line_idx)
#	var line:String = get_line_by_idx1(output.text, line_idx)
	if !line: return





	var path_and_lineno:Array = find_gdscript_path_and_lineno(line)
	if not path_and_lineno: return

	var path:String = path_and_lineno[0]
	var lineno:int = path_and_lineno[1]

	var scr:GDScript = load(path)
	if not scr: return

	get_editor_interface().edit_resource(scr)
	get_editor_interface().get_script_editor().goto_line(lineno)






# ====================== utils =============================

# node utils

static func set_parent(node:Node, new_parent:Node, idx:= -1):
	var parent = node.get_parent()
	if parent:
		parent.remove_child(node)
	new_parent.add_child(node)
	if !idx==-1:
		new_parent.move_child(node, idx)

static func get_child_by_class(node:Node, cls:String):
	for child in node.get_children():
		if child.get_class() == cls:
			return child

static func get_node_by_class_path(node:Node, class_path:Array)->Node:
	var res:Node

	var stack = []
	var depths = []

	var first = class_path[0]
	for c in node.get_children():
		if c.get_class() == first:
			stack.push_back(c)
			depths.push_back(0)

	if not stack: return res
	
	var max_ = class_path.size()-1

	while stack:
		var d = depths.pop_back()
		var n = stack.pop_back()

		if d>max_:
			continue
		if n.get_class() == class_path[d]:
			if d == max_:
				res = n
				return res

			for c in n.get_children():
				stack.push_back(c)
				depths.push_back(d+1)

	return res




# string/script utils

# lineno starts from 0
static func find_gdscript_path_and_lineno(s:String)->Array:
	var fake_array:Array

	var meta_name = 'gds_path_and_lineno'
	var regex:RegEx
	if Engine.has_meta(meta_name):
		regex = Engine.get_meta(meta_name)
	else:
		regex =  RegEx.new()
		regex.compile("(res://.*.gd):(\\d+)")
		Engine.set_meta(meta_name, regex)

	var res = regex.search(s)
	if !res: return fake_array
	res = res.strings
	return [res[1], int(res[2])-1]




# RichTextLabel utils

static func get_line_idx_by_y(rich_label:RichTextLabel, local_y:float)->int:
	if rich_label.get_line_count() == 0:
		return -1
	var content_h = rich_label.get_content_height()
	if content_h<local_y:
		return -1
	var vscroll:VScrollBar = rich_label.get_v_scroll()
	var vscroll_val = vscroll.value
	return int(local_y+vscroll_val)/int(content_h/rich_label.get_line_count())


static func get_line_by_idx(rich_label:RichTextLabel, idx:int)->String:
	var res:String
	var arr = rich_label.text.split("\n")
	if arr.size()<=idx: return res
	return arr[idx]


# EditorLog utils

static func get_output(base:Control)->RichTextLabel:
	return get_output_by_log(get_log(base))

static func get_output_by_log(editor_log:VBoxContainer)->RichTextLabel:
	return get_child_by_class(editor_log, 'RichTextLabel') as RichTextLabel


static func get_log(base:Control)->VBoxContainer:
	var result: VBoxContainer = get_node_by_class_path(
		base, [
			'VBoxContainer', 
			'HSplitContainer',
			'HSplitContainer',
			'HSplitContainer',
			'VBoxContainer',
			'VSplitContainer',
			'PanelContainer',
			'VBoxContainer',
			'EditorLog'
		]
	)
	return result
	

# doesn't check line count
static func get_line_by_idx1(s:String, idx:int)->String:
	var pos: = 0
	for i in idx:
		pos = s.find('\n', pos+1)
		if pos == -1:return ''

	var end: = 0
	for i in range(pos+1, s.length()):
		end+=1
		if s[i] == '\n': break
	return s.substr(pos, end+1)
