/**
 * Audio Player Component for Dutch Language Learning Application.
 *
 * Provides audio playback controls with segment playback support,
 * playback speed control, and loop functionality.
 */

/**
 * Available playback speeds.
 * @type {number[]}
 */
export const PLAYBACK_SPEEDS = [0.5, 0.75, 1.0, 1.25, 1.5];

/**
 * Default playback speed.
 * @type {number}
 */
export const DEFAULT_SPEED = 1.0;

/**
 * Audio Player class for managing audio playback.
 *
 * Features:
 * - Play specific time segments
 * - Adjustable playback speed
 * - Loop mode for repeating segments
 * - Progress tracking
 *
 * @example
 * const audio = document.getElementById('audio');
 * const player = new AudioPlayer(audio);
 *
 * player.onTimeUpdate((time, duration) => {
 *     console.log(`${time}s / ${duration}s`);
 * });
 *
 * player.playSegment(10.5, 15.2);
 */
export class AudioPlayer {
    /**
     * Create an AudioPlayer instance.
     *
     * @param {HTMLAudioElement} audioElement - The HTML audio element to control
     */
    constructor(audioElement) {
        /** @type {HTMLAudioElement} */
        this.audio = audioElement;

        /** @type {{start: number, end: number}|null} */
        this.currentSegment = null;

        /** @type {boolean} */
        this.isLooping = false;

        /** @type {number} */
        this.playbackRate = DEFAULT_SPEED;

        /** @type {Set<function>} */
        this._timeUpdateCallbacks = new Set();

        /** @type {Set<function>} */
        this._playStateCallbacks = new Set();

        /** @type {Set<function>} */
        this._segmentEndCallbacks = new Set();

        /** @type {Set<function>} */
        this._loadedCallbacks = new Set();

        /** @type {Set<function>} */
        this._errorCallbacks = new Set();

        this._setupEventListeners();
    }

    /**
     * Set up event listeners on the audio element.
     * @private
     */
    _setupEventListeners() {
        // Time update - check for segment end
        this.audio.addEventListener('timeupdate', () => {
            const currentTime = this.audio.currentTime;
            const duration = this.audio.duration || 0;

            // Notify time update listeners
            this._timeUpdateCallbacks.forEach(cb => cb(currentTime, duration));

            // Check if we've reached the end of the current segment
            if (this.currentSegment && currentTime >= this.currentSegment.end) {
                if (this.isLooping) {
                    // Loop back to segment start
                    this.audio.currentTime = this.currentSegment.start;
                } else {
                    // Stop at segment end
                    this.audio.pause();
                    this.audio.currentTime = this.currentSegment.end;
                    this._segmentEndCallbacks.forEach(cb => cb(this.currentSegment));
                    this.currentSegment = null;
                }
            }
        });

        // Play/pause state changes
        this.audio.addEventListener('play', () => {
            this._playStateCallbacks.forEach(cb => cb(true));
        });

        this.audio.addEventListener('pause', () => {
            this._playStateCallbacks.forEach(cb => cb(false));
        });

        // Audio loaded
        this.audio.addEventListener('loadedmetadata', () => {
            this._loadedCallbacks.forEach(cb => cb(this.audio.duration));
        });

        this.audio.addEventListener('canplay', () => {
            this._loadedCallbacks.forEach(cb => cb(this.audio.duration));
        });

        // Error handling
        this.audio.addEventListener('error', (e) => {
            const error = this.audio.error;
            let message = 'Unknown audio error';

            if (error) {
                switch (error.code) {
                    case MediaError.MEDIA_ERR_ABORTED:
                        message = 'Audio playback was aborted';
                        break;
                    case MediaError.MEDIA_ERR_NETWORK:
                        message = 'Network error while loading audio';
                        break;
                    case MediaError.MEDIA_ERR_DECODE:
                        message = 'Audio decoding error';
                        break;
                    case MediaError.MEDIA_ERR_SRC_NOT_SUPPORTED:
                        message = 'Audio format not supported';
                        break;
                }
            }

            this._errorCallbacks.forEach(cb => cb(message, error));
        });

        // Audio ended (natural end of file)
        this.audio.addEventListener('ended', () => {
            this.currentSegment = null;
            this._playStateCallbacks.forEach(cb => cb(false));
        });
    }

    /**
     * Load an audio source.
     *
     * @param {string} src - URL of the audio file
     * @returns {Promise<number>} - Resolves with duration when loaded
     */
    load(src) {
        return new Promise((resolve, reject) => {
            const onLoaded = (duration) => {
                this._loadedCallbacks.delete(onLoaded);
                this._errorCallbacks.delete(onError);
                resolve(duration);
            };

            const onError = (message, error) => {
                this._loadedCallbacks.delete(onLoaded);
                this._errorCallbacks.delete(onError);
                reject(new Error(message));
            };

            this._loadedCallbacks.add(onLoaded);
            this._errorCallbacks.add(onError);

            this.audio.src = src;
            this.audio.load();
        });
    }

    /**
     * Play a specific time segment.
     *
     * @param {number} startTime - Start time in seconds
     * @param {number} endTime - End time in seconds
     * @returns {Promise<void>} - Resolves when playback starts
     */
    async playSegment(startTime, endTime) {
        // Validate times
        if (startTime < 0) startTime = 0;
        if (endTime <= startTime) {
            throw new Error('End time must be greater than start time');
        }

        // Set the segment
        this.currentSegment = {
            start: startTime,
            end: endTime,
        };

        // Seek to start and play
        this.audio.currentTime = startTime;

        try {
            await this.audio.play();
        } catch (error) {
            this.currentSegment = null;
            throw error;
        }
    }

    /**
     * Play from current position (or resume).
     *
     * @returns {Promise<void>}
     */
    async play() {
        await this.audio.play();
    }

    /**
     * Pause playback.
     */
    pause() {
        this.audio.pause();
    }

    /**
     * Toggle play/pause state.
     *
     * @returns {Promise<boolean>} - New playing state
     */
    async togglePlay() {
        if (this.audio.paused) {
            await this.play();
            return true;
        } else {
            this.pause();
            return false;
        }
    }

    /**
     * Stop playback and clear segment.
     */
    stop() {
        this.audio.pause();
        this.currentSegment = null;
    }

    /**
     * Seek to a specific time.
     *
     * @param {number} time - Time in seconds
     */
    seek(time) {
        if (time < 0) time = 0;
        if (time > this.audio.duration) time = this.audio.duration;
        this.audio.currentTime = time;
    }

    /**
     * Seek by a relative offset.
     *
     * @param {number} offset - Seconds to seek (positive = forward, negative = backward)
     */
    seekRelative(offset) {
        this.seek(this.audio.currentTime + offset);
    }

    /**
     * Set the playback speed.
     *
     * @param {number} rate - Playback rate (0.5 to 2.0)
     */
    setPlaybackRate(rate) {
        if (rate < 0.25) rate = 0.25;
        if (rate > 2.0) rate = 2.0;
        this.playbackRate = rate;
        this.audio.playbackRate = rate;
    }

    /**
     * Get the current playback speed.
     *
     * @returns {number}
     */
    getPlaybackRate() {
        return this.playbackRate;
    }

    /**
     * Set loop mode for segment playback.
     *
     * @param {boolean} enabled - Whether to loop
     */
    setLoop(enabled) {
        this.isLooping = enabled;
    }

    /**
     * Toggle loop mode.
     *
     * @returns {boolean} - New loop state
     */
    toggleLoop() {
        this.isLooping = !this.isLooping;
        return this.isLooping;
    }

    /**
     * Check if currently looping.
     *
     * @returns {boolean}
     */
    getLoop() {
        return this.isLooping;
    }

    /**
     * Get current playback time.
     *
     * @returns {number} - Current time in seconds
     */
    getCurrentTime() {
        return this.audio.currentTime;
    }

    /**
     * Get total duration.
     *
     * @returns {number} - Duration in seconds
     */
    getDuration() {
        return this.audio.duration || 0;
    }

    /**
     * Check if audio is currently playing.
     *
     * @returns {boolean}
     */
    isPlaying() {
        return !this.audio.paused;
    }

    /**
     * Check if audio is ready to play.
     *
     * @returns {boolean}
     */
    isReady() {
        return this.audio.readyState >= 2;
    }

    /**
     * Get the current segment being played.
     *
     * @returns {{start: number, end: number}|null}
     */
    getCurrentSegment() {
        return this.currentSegment;
    }

    /**
     * Clear the current segment (play to end of file).
     */
    clearSegment() {
        this.currentSegment = null;
    }

    /**
     * Set volume level.
     *
     * @param {number} volume - Volume level (0.0 to 1.0)
     */
    setVolume(volume) {
        if (volume < 0) volume = 0;
        if (volume > 1) volume = 1;
        this.audio.volume = volume;
    }

    /**
     * Get current volume level.
     *
     * @returns {number}
     */
    getVolume() {
        return this.audio.volume;
    }

    /**
     * Mute or unmute audio.
     *
     * @param {boolean} muted - Whether to mute
     */
    setMuted(muted) {
        this.audio.muted = muted;
    }

    /**
     * Check if audio is muted.
     *
     * @returns {boolean}
     */
    isMuted() {
        return this.audio.muted;
    }

    // Event subscription methods

    /**
     * Subscribe to time update events.
     *
     * @param {function(number, number): void} callback - Called with (currentTime, duration)
     * @returns {function} - Unsubscribe function
     */
    onTimeUpdate(callback) {
        this._timeUpdateCallbacks.add(callback);
        return () => this._timeUpdateCallbacks.delete(callback);
    }

    /**
     * Subscribe to play state change events.
     *
     * @param {function(boolean): void} callback - Called with isPlaying
     * @returns {function} - Unsubscribe function
     */
    onPlayStateChange(callback) {
        this._playStateCallbacks.add(callback);
        return () => this._playStateCallbacks.delete(callback);
    }

    /**
     * Subscribe to segment end events.
     *
     * @param {function({start: number, end: number}): void} callback - Called when segment ends
     * @returns {function} - Unsubscribe function
     */
    onSegmentEnd(callback) {
        this._segmentEndCallbacks.add(callback);
        return () => this._segmentEndCallbacks.delete(callback);
    }

    /**
     * Subscribe to audio loaded events.
     *
     * @param {function(number): void} callback - Called with duration
     * @returns {function} - Unsubscribe function
     */
    onLoaded(callback) {
        this._loadedCallbacks.add(callback);
        return () => this._loadedCallbacks.delete(callback);
    }

    /**
     * Subscribe to error events.
     *
     * @param {function(string, MediaError): void} callback - Called with error message
     * @returns {function} - Unsubscribe function
     */
    onError(callback) {
        this._errorCallbacks.add(callback);
        return () => this._errorCallbacks.delete(callback);
    }

    /**
     * Clean up and release resources.
     */
    destroy() {
        this.stop();
        this._timeUpdateCallbacks.clear();
        this._playStateCallbacks.clear();
        this._segmentEndCallbacks.clear();
        this._loadedCallbacks.clear();
        this._errorCallbacks.clear();
    }
}

/**
 * Format time in seconds to MM:SS or HH:MM:SS string.
 *
 * @param {number} seconds - Time in seconds
 * @returns {string} - Formatted time string
 */
export function formatTime(seconds) {
    if (!seconds || !isFinite(seconds)) {
        return '0:00';
    }

    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = Math.floor(seconds % 60);

    if (hours > 0) {
        return `${hours}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }

    return `${minutes}:${secs.toString().padStart(2, '0')}`;
}

/**
 * Parse time string to seconds.
 *
 * @param {string} timeStr - Time string (MM:SS or HH:MM:SS)
 * @returns {number} - Time in seconds
 */
export function parseTime(timeStr) {
    const parts = timeStr.split(':').map(Number);

    if (parts.length === 3) {
        return parts[0] * 3600 + parts[1] * 60 + parts[2];
    } else if (parts.length === 2) {
        return parts[0] * 60 + parts[1];
    }

    return Number(timeStr) || 0;
}

// Default export
export default {
    AudioPlayer,
    PLAYBACK_SPEEDS,
    DEFAULT_SPEED,
    formatTime,
    parseTime,
};
