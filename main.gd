extends Control

@onready var stream = $AudioStreamPlayer
@onready var devices_container = $InputDevices
@onready var osc_bg = $Oscilloscope_bg
@onready var osc_viewport = $Oscilloscope_bg/OscRect/OscViewport
@onready var blur_texture: TextureRect  = $Oscilloscope_bg/OscVC/Feedback/Blur
@onready var line : Line2D = osc_bg.get_node("OscRect/OscViewport/Line")
var button_scene = preload("res://button.tscn")
var capture : AudioEffectCapture
var lowpass : AudioEffectLowPassFilter
var highpass : AudioEffectHighPassFilter
var compressor : AudioEffectCompressor
var samples = PackedVector2Array()
var update_samples = 256
var max_samples = 8192
var sample_rate = 44100
var C4 = 261.6256
var curr_note = 0
var auto = false
var input_amp = 1
var note_names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
var min_note = -64 # G# -3
var max_note = 9 # A4
var osc_padding = 5
var old_texture: Texture = Texture.new()
var even = true
var feedback_effect = true
#C1 - B1
var note_ranges = []

var last_texture: Texture2D = ImageTexture.create_from_image(load("res://transparent.png"))
var save_path = "user://settings.json"

func load_save():
	if(!FileAccess.file_exists(save_path)): return
	var savefile = JSON.parse_string(FileAccess.open(save_path, FileAccess.READ).get_as_text())
	set_input_device(savefile["input_device"])
	$ScrollContainer/Panel/Controls/Amp/Amp.value = savefile["amplification"]
	$ScrollContainer/Panel/Controls/TimeWindow/OscSize.value = savefile["oscsize"]
	$ScrollContainer/Panel/Controls/CheckButton.button_pressed = savefile["auto"]
	$ScrollContainer/Panel/Controls/FreqBase.value = savefile["freqbase"]
	$ScrollContainer/Panel/Controls/HighPass/Cutoff.value = savefile["highpass"]
	$ScrollContainer/Panel/Controls/LowPass/Cutoff.value = savefile["lowpass"]
	$ScrollContainer/Panel/Controls/Decay/Feedback.value = savefile["feedback"]
	$ScrollContainer/Panel/Controls/Compressor.button_pressed = savefile["compressor"]
	
func save():
	var savejson = {
		"input_device": AudioServer.input_device,
		"amplification": $ScrollContainer/Panel/Controls/Amp/Amp.value,
		"oscsize": $ScrollContainer/Panel/Controls/TimeWindow/OscSize.value,
		"auto": $ScrollContainer/Panel/Controls/CheckButton.button_pressed,
		"freqbase": $ScrollContainer/Panel/Controls/FreqBase.value,
		"highpass": $ScrollContainer/Panel/Controls/HighPass/Cutoff.value,
		"lowpass": $ScrollContainer/Panel/Controls/LowPass/Cutoff.value,
		"feedback": $ScrollContainer/Panel/Controls/Decay/Feedback.value,
		"compressor": $ScrollContainer/Panel/Controls/Compressor.button_pressed
	}
	var savefile = FileAccess.open(save_path, FileAccess.WRITE)
	savefile.store_string(JSON.stringify(savejson))
	savefile.close()

func set_input_device(device_string):
	AudioServer.input_device = device_string
	sample_rate = AudioServer.get_input_mix_rate()
	change_note(0)
	_on_osc_time_value_changed($ScrollContainer/Panel/Controls/TimeWindow/OscSize.value)
	$InputDevices.fold()
	
	

func screen_percent(p):
	return DisplayServer.screen_get_size(DisplayServer.SCREEN_OF_MAIN_WINDOW) * p / 100

func get_devices() -> void:
	for c in devices_container.get_child(0).get_children():
		c.free()
	devices_container.size.y = AudioServer.get_input_device_list().size() * screen_percent(10).y
	for d in AudioServer.get_input_device_list():
		var button : Button = button_scene.instantiate()
		button.text = d
		button.pressed.connect(set_input_device.bind(button.text))
		devices_container.get_child(0).add_child(button)
	
func set_update_samples(pitch): #pitch in hz
	update_samples = sample_rate / pitch
	draw_helper_lines()
	
func st_to_pitch(st):
	return C4 * pow(2, st/12.0)
	
func set_note(): # semitones over/under C4
	var pitch = st_to_pitch(curr_note)
	set_update_samples(pitch)
	$ScrollContainer/Panel/Controls/Note/NoteText/Freq.text = "(" + str(snapped(pitch, 0.1)) + " Hz)"
	
func draw_helper_lines():
	if !is_node_ready():
		return
	var bglines = osc_bg.get_node("SubViewportContainer/SubViewport/BgLines")
	for i in bglines.get_children():
		i.queue_free()
	var start_x = osc_padding
	var end_x = osc_bg.size.x - osc_padding
	var top_y = osc_padding
	var bottom_y = osc_bg.size.y - osc_padding
	
	var step_x = update_samples / max_samples * (end_x - start_x)
	var curr_x = end_x - step_x
	while(curr_x > start_x):
		var l = Line2D.new()
		l.use_parent_material = true
		l.add_point(Vector2(curr_x, top_y))
		l.add_point(Vector2(curr_x, bottom_y))
		l.default_color = Color(0.745, 0.745, 0.745, 0.514)
		l.width = 4
		l.begin_cap_mode = Line2D.LINE_CAP_ROUND
		l.end_cap_mode = Line2D.LINE_CAP_ROUND
		bglines.add_child(l)
		curr_x -= step_x
	
	
func _ready() -> void:
	get_devices()
	set_input_device("Default")
	highpass = AudioServer.get_bus_effect(1, 0)
	lowpass = AudioServer.get_bus_effect(1, 1)
	compressor = AudioServer.get_bus_effect(1, 2)
	capture = AudioServer.get_bus_effect(1, 3)
	#fft = AudioServer.get_bus_effect_instance(1, 3)
	load_save()
	_on_lp_cutoff_value_changed($ScrollContainer/Panel/Controls/LowPass/Cutoff.value)
	_on_hp_cutoff_value_changed($ScrollContainer/Panel/Controls/HighPass/Cutoff.value)
	change_note(-24) #C2
	_on_auto_button_toggled(auto)
	
	_on_freq_base_value_changed($ScrollContainer/Panel/Controls/FreqBase.value)
	

func update_osc():
	line.clear_points()
	
	var curr_x = osc_padding
	var top_y = osc_padding
	var bottom_y = osc_bg.size.y - osc_padding
	var mid_y = (top_y + bottom_y) / 2
	
	var step_x = (osc_bg.size.x - osc_padding * 2) / (samples.size() - 1)
	var last_x = 0
	for s in samples:
		if(curr_x - last_x >= 1): # draw only as many samples as there are pixels
			line.add_point(Vector2(curr_x, clamp(s.x * (top_y - mid_y) * input_amp + mid_y, top_y, bottom_y)))
			last_x = curr_x
		curr_x += step_x


func _physics_process(_delta: float) -> void:
	if(capture.can_get_buffer(update_samples)):
		line.queue_redraw()
		samples.append_array(capture.get_buffer(update_samples))
		if(samples.size() > max_samples):
			samples = samples.slice(samples.size() - max_samples)
		$Oscilloscope_bg/OscRect/OscViewport.size = $Oscilloscope_bg/OscVC/Feedback.size
		update_osc()
		
		
func _process(_delta: float) -> void:
	if(feedback_effect): 
		blur_texture.material.set_shader_parameter("prev_frame", last_texture)
		last_texture = ImageTexture.create_from_image($Oscilloscope_bg/OscVC/Feedback.get_texture().get_image())
		
	


func change_note(amt: int) -> void:
	curr_note += amt
	set_note()
	
	if(curr_note <= min_note): $ScrollContainer/Panel/Controls/Note/NoteText/NoteDown.disabled = true
	elif(!auto): $ScrollContainer/Panel/Controls/Note/NoteText/NoteDown.disabled = false
	if(curr_note >= max_note): $ScrollContainer/Panel/Controls/Note/NoteText/NoteUp.disabled = true
	elif(!auto): $ScrollContainer/Panel/Controls/Note/NoteText/NoteUp.disabled = false
	
	$ScrollContainer/Panel/Controls/Note/NoteText.text = note_names[curr_note % 12] + " " + str(4 + int(floor(curr_note / 12.0)))

func _on_input_devices_folding_changed(is_folded: bool) -> void:
	if(!is_folded): get_devices()


func _on_osc_time_value_changed(value: float) -> void:
	max_samples = value / 1000 * sample_rate
	$ScrollContainer/Panel/Controls/TimeWindow/Label.text = "Oscilloscope time window\n" + str(round(value)) + " ms"
	draw_helper_lines()


func _on_amp_value_changed(value: float) -> void:
	input_amp = value
	$ScrollContainer/Panel/Controls/Amp/Label.text = "Amplification\n" + str(snapped(value, 0.1))


func _on_freq_base_value_changed(value: float) -> void:
	C4 = value / pow(2, 9/12.0)
	set_note()
	NoteDetector.C0_HZ = st_to_pitch(-48)
	#note_ranges = []
	#for i in range(12):
	#	note_ranges.push_back([0, 0])
	#	note_ranges[i][0] = st_to_pitch(i-0.1)
	#	note_ranges[i][1] = st_to_pitch(i+0.1)
	#print(note_ranges)
	


func _on_hp_cutoff_value_changed(value: float) -> void:
	highpass.cutoff_hz = value
	$ScrollContainer/Panel/Controls/HighPass/Label.text = "High pass filter cutoff\n" + str(int(value)) + " Hz"


func _on_lp_cutoff_value_changed(value: float) -> void:
	lowpass.cutoff_hz = value
	$ScrollContainer/Panel/Controls/LowPass/Label.text = "Low pass filter cutoff\n" + str(int(value)) + " Hz"


func _on_auto_button_toggled(toggled_on: bool) -> void:
	auto = toggled_on
	$ScrollContainer/Panel/Controls/Note/NoteText/NoteUp.disabled = toggled_on
	$ScrollContainer/Panel/Controls/Note/NoteText/NoteDown.disabled = toggled_on


func _on_note_detected(event: NoteDetectEvent) -> void:
	if auto:
		change_note(event.note_index - 12 * event.note_octave - 36 - curr_note)


func _on_feedback_value_changed(value: float) -> void:
	blur_texture.material.set_shader_parameter("feedback", value)
	feedback_effect = value > 0.01
	if(!feedback_effect):
		blur_texture.material.set_shader_parameter("prev_frame", ImageTexture.create_from_image(load("res://transparent.png")))
	$ScrollContainer/Panel/Controls/Decay/Label.text = "Feedback effect amount\n" + str(value)
		
	


func _on_compressor_toggled(toggled_on: bool) -> void:
	compressor.mix = 1.0 if toggled_on else 0.0


func _on_tree_exiting() -> void:
	save()
