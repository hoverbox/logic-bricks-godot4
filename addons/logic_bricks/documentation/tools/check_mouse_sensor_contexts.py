from pathlib import Path

src = Path(__file__).resolve().parents[2] / 'bricks' / 'sensors' / 'common' / 'mouse_sensor.gd'
text = src.read_text(encoding='utf-8')
required = [
    'if node is Control:',
    'elif node is Node2D:',
    'get_world_2d().direct_space_state.intersect_point',
    'get_viewport().gui_get_hovered_control()',
    'get_world_3d().direct_space_state',
]
missing = [item for item in required if item not in text]
assert not missing, f'Mouse sensor context support missing: {missing}'
print('Mouse sensor 3D/2D/UI hover context check passed.')
