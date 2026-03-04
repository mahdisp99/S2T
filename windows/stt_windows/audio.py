from __future__ import annotations

from collections.abc import Callable

import numpy as np
import sounddevice as sd


class AudioRecorder:
    def __init__(self, target_sample_rate: int = 16000, blocksize: int = 2048) -> None:
        self.target_sample_rate = target_sample_rate
        self.blocksize = blocksize
        self.input_sample_rate = target_sample_rate
        self._stream: sd.RawInputStream | None = None
        self._on_audio_data: Callable[[bytes], None] | None = None
        self._on_level: Callable[[float], None] | None = None

    def start(
        self,
        on_audio_data: Callable[[bytes], None],
        on_level: Callable[[float], None] | None = None,
    ) -> None:
        if self._stream is not None:
            return

        self._on_audio_data = on_audio_data
        self._on_level = on_level

        device_info = sd.query_devices(kind="input")
        raw_input_rate = int(round(float(device_info["default_samplerate"])))
        self.input_sample_rate = raw_input_rate if raw_input_rate > 0 else self.target_sample_rate

        self._stream = sd.RawInputStream(
            samplerate=self.input_sample_rate,
            channels=1,
            dtype="float32",
            blocksize=self.blocksize,
            callback=self._on_audio_block,
        )
        self._stream.start()
        print(
            f"[audio] capture started: {self.input_sample_rate} Hz -> {self.target_sample_rate} Hz"
        )

    def stop(self) -> None:
        if self._stream is None:
            return

        self._stream.stop()
        self._stream.close()
        self._stream = None
        self._on_audio_data = None
        self._on_level = None
        print("[audio] capture stopped")

    def _on_audio_block(self, indata: bytes, frames: int, time_info: dict, status: sd.CallbackFlags) -> None:
        if status:
            print(f"[audio] callback status: {status}")

        float_samples = np.frombuffer(indata, dtype=np.float32)
        if float_samples.size == 0:
            return

        if self._on_level is not None:
            rms_level = float(np.sqrt(np.mean(np.square(float_samples))))
            normalized = max(0.0, min(rms_level * 4.0, 1.0))
            self._on_level(normalized)

        if self.input_sample_rate != self.target_sample_rate:
            float_samples = _resample(float_samples, self.input_sample_rate, self.target_sample_rate)

        pcm = np.clip(float_samples, -1.0, 1.0)
        int16_bytes = (pcm * 32767.0).astype(np.int16).tobytes()
        if self._on_audio_data is not None:
            self._on_audio_data(int16_bytes)


def _resample(samples: np.ndarray, source_rate: int, target_rate: int) -> np.ndarray:
    if source_rate == target_rate or samples.size == 0:
        return samples

    output_length = int(samples.size * target_rate / source_rate)
    if output_length <= 0:
        return np.empty(0, dtype=np.float32)

    source_indices = np.arange(samples.size, dtype=np.float32)
    target_indices = np.linspace(
        0.0,
        float(samples.size - 1),
        num=output_length,
        endpoint=False,
        dtype=np.float32,
    )

    resampled = np.interp(target_indices, source_indices, samples)
    return resampled.astype(np.float32)

