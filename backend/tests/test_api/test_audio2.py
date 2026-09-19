from app.api.v1.endpoints.audio import check_magic_bytes


def test_audio_magic_bytes_rejects_disguised_text():
    assert not check_magic_bytes(
        b"this is just a normal text file pretending to be audio"
    )


def test_audio_magic_bytes_accepts_wav():
    assert check_magic_bytes(b"RIFF\x24\x00\x00\x00WAVEfmt ")
