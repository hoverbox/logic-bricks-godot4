extends RefCounted

var panel = null

func setup(target_panel) -> void:
    panel = target_panel

func sync_graph_ui_to_bricks() -> void:
    for graph_node in panel.graph_edit.get_children():
        if not (graph_node is GraphNode):
            continue
        if not graph_node.has_meta("brick_data"):
            continue

        var brick_data = graph_node.get_meta("brick_data")
        var brick_instance = brick_data.get("brick_instance", null)
        if brick_instance == null:
            continue

        for child in graph_node.get_children():
            if not child.has_meta("property_name"):
                continue

            var property_name = str(child.get_meta("property_name"))
            var control = child.get_node_or_null("PropertyControl_" + property_name)

            if control == null:
                if child is CheckBox:
                    brick_instance.set_property(property_name, child.button_pressed)
                continue

            if control is SpinBox:
                var spinbox: SpinBox = control
                var current_value = spinbox.value
                var property_type = TYPE_NIL
                for prop_def in brick_instance.get_property_definitions():
                    if prop_def.get("name", "") == property_name:
                        property_type = int(prop_def.get("type", TYPE_NIL))
                        break
                if property_type == TYPE_INT:
                    brick_instance.set_property(property_name, int(current_value))
                else:
                    brick_instance.set_property(property_name, current_value)
            elif control is CheckBox:
                brick_instance.set_property(property_name, control.button_pressed)
            elif control is OptionButton:
                var option_button: OptionButton = control
                var selected = option_button.selected
                if selected >= 0:
                    var value = option_button.get_item_metadata(selected)
                    if value == null:
                        value = option_button.get_item_text(selected).to_lower().replace(" ", "_")
                    brick_instance.set_property(property_name, value)
            elif control is LineEdit:
                var line_edit: LineEdit = control
                if not line_edit.editable and not line_edit.tooltip_text.is_empty():
                    brick_instance.set_property(property_name, line_edit.tooltip_text)
                else:
                    brick_instance.set_property(property_name, line_edit.text)
            elif control is ColorPickerButton:
                brick_instance.set_property(property_name, control.color)

func extract_chains_from_graph(include_incomplete: bool = false) -> Array:
    var chains = []
    var connections = panel.graph_edit.get_connection_list()

    var controller_nodes = []
    for child in panel.graph_edit.get_children():
        if child is GraphNode and child.has_meta("brick_data"):
            var brick_data = child.get_meta("brick_data")
            if brick_data["brick_type"] == "controller":
                controller_nodes.append(child)

    for controller_node in controller_nodes:
        var chain = build_chain_from_controller(controller_node, connections)
        var is_script_controller = chain["controller"] != null and chain["controller"].get("type", "") == "ScriptController"
        var has_sensors = chain["sensors"].size() > 0
        var has_actuators = chain["actuators"].size() > 0
        var is_complete = has_sensors and (has_actuators or is_script_controller)
        if is_complete or include_incomplete:
            var chain_name = get_chain_name_for_controller(controller_node)
            chains.append({
                "name": chain_name,
                "sensors": chain["sensors"],
                "controllers": [chain["controller"]] if chain["controller"] else [],
                "actuators": chain["actuators"]
            })

    return chains

func build_chain_from_controller(controller_node: GraphNode, connections: Array) -> Dictionary:
    var sensors = []
    var actuators = []
    var controller_brick = null

    if controller_node.has_meta("brick_data"):
        var brick_data = controller_node.get_meta("brick_data")
        controller_brick = brick_data["brick_instance"].serialize()

    var input_nodes = trace_inputs(controller_node.name, connections)
    for from_node in input_nodes:
        if from_node.has_meta("brick_data"):
            var brick_data = from_node.get_meta("brick_data")
            if brick_data["brick_type"] == "sensor":
                var serialized_data = brick_data["brick_instance"].serialize()
                sensors.append(serialized_data)

    var output_nodes = trace_outputs(controller_node.name, connections)
    for to_node in output_nodes:
        if to_node.has_meta("brick_data"):
            var brick_data = to_node.get_meta("brick_data")
            if brick_data["brick_type"] == "actuator":
                actuators.append(brick_data["brick_instance"].serialize())

    return {
        "sensors": sensors,
        "controller": controller_brick,
        "actuators": actuators
    }

func trace_inputs(node_name: String, connections: Array) -> Array:
    var results = []
    for conn in connections:
        if conn["to_node"] == node_name:
            var from_node = panel.graph_edit.get_node_or_null(NodePath(conn["from_node"]))
            if from_node:
                if from_node.has_meta("is_reroute"):
                    results.append_array(trace_inputs(from_node.name, connections))
                else:
                    results.append(from_node)
    return results

func trace_outputs(node_name: String, connections: Array) -> Array:
    var results = []
    for conn in connections:
        if conn["from_node"] == node_name:
            var to_node = panel.graph_edit.get_node_or_null(NodePath(conn["to_node"]))
            if to_node:
                if to_node.has_meta("is_reroute"):
                    results.append_array(trace_outputs(to_node.name, connections))
                else:
                    results.append(to_node)
    return results

func get_chain_name_for_controller(controller_node: GraphNode) -> String:
    if controller_node.has_meta("brick_data"):
        var brick_data = controller_node.get_meta("brick_data")
        var brick_class = brick_data["brick_class"]
        return brick_class.to_lower().replace("controller", "") + "_" + controller_node.name.replace("brick_node_", "")

    return controller_node.name.replace("brick_node_", "chain_")
