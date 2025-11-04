import pytest
from commands import generate_inverse_command

def test_generate_inverse_command():
    original = {
        'command_id': 'test123',
        'target_id': 'device1',
        'command_type': 'THROTTLE',
        'parameters': {'rate': '50%'}
    }
    inverse = generate_inverse_command(original)
    assert inverse['command_type'] == 'UNTHROTTLE'
    assert 'rollback_test123' in inverse['command_id']