/**
 * API Client for Dutch Language Learning Application.
 *
 * Provides methods for communicating with the backend REST API.
 * Handles all HTTP requests, error handling, and response parsing.
 */

/**
 * Base URL for API endpoints.
 * @type {string}
 */
const API_BASE = '/api';

/**
 * Custom error class for API errors.
 */
export class ApiError extends Error {
    /**
     * Create an API error.
     * @param {string} message - Error message
     * @param {number} status - HTTP status code
     * @param {Object} data - Additional error data
     */
    constructor(message, status, data = null) {
        super(message);
        this.name = 'ApiError';
        this.status = status;
        this.data = data;
    }
}

/**
 * Make an HTTP request to the API.
 *
 * @param {string} endpoint - API endpoint path
 * @param {Object} options - Fetch options
 * @returns {Promise<Object>} - Parsed JSON response
 * @throws {ApiError} - If the request fails
 */
async function request(endpoint, options = {}) {
    const url = `${API_BASE}${endpoint}`;

    const defaultOptions = {
        headers: {
            'Accept': 'application/json',
        },
    };

    // Only add Content-Type for JSON requests (not FormData)
    if (options.body && !(options.body instanceof FormData)) {
        defaultOptions.headers['Content-Type'] = 'application/json';
    }

    const finalOptions = {
        ...defaultOptions,
        ...options,
        headers: {
            ...defaultOptions.headers,
            ...options.headers,
        },
    };

    try {
        const response = await fetch(url, finalOptions);

        // Handle non-JSON responses for DELETE
        if (response.status === 204) {
            return null;
        }

        let data;
        const contentType = response.headers.get('content-type');

        if (contentType && contentType.includes('application/json')) {
            data = await response.json();
        } else {
            data = await response.text();
        }

        if (!response.ok) {
            const errorMessage = typeof data === 'object' && data.detail
                ? data.detail
                : `Request failed with status ${response.status}`;
            throw new ApiError(errorMessage, response.status, data);
        }

        return data;
    } catch (error) {
        if (error instanceof ApiError) {
            throw error;
        }
        // Network or other error
        throw new ApiError(
            error.message || 'Network error. Please check your connection.',
            0
        );
    }
}

/**
 * Get all projects.
 *
 * @returns {Promise<Object>} - Response containing projects array
 *
 * @example
 * const { projects } = await getProjects();
 * projects.forEach(p => console.log(p.name));
 */
export async function getProjects() {
    return request('/projects');
}

/**
 * Get a single project by ID with all sentences.
 *
 * @param {string} id - Project UUID
 * @returns {Promise<Object>} - Project detail with sentences
 *
 * @example
 * const project = await getProject('abc-123');
 * console.log(project.sentences.length);
 */
export async function getProject(id) {
    return request(`/projects/${id}`);
}

/**
 * Delete a project by ID.
 *
 * @param {string} id - Project UUID
 * @returns {Promise<Object>} - Deletion confirmation
 *
 * @example
 * await deleteProject('abc-123');
 */
export async function deleteProject(id) {
    return request(`/projects/${id}`, {
        method: 'DELETE',
    });
}

/**
 * Upload a new project file.
 *
 * @param {File} file - The file to upload
 * @param {string} name - Project name (optional, defaults to filename)
 * @param {function} onProgress - Progress callback (0-100)
 * @returns {Promise<Object>} - Created project info
 *
 * @example
 * const file = document.querySelector('input[type="file"]').files[0];
 * const project = await uploadProject(file, 'My Lesson', (progress) => {
 *     console.log(`Upload: ${progress}%`);
 * });
 */
export async function uploadProject(file, name = null, onProgress = null) {
    const formData = new FormData();
    formData.append('file', file);

    // If name provided, use it; otherwise API will use filename
    if (name) {
        formData.append('name', name);
    }

    // Use XMLHttpRequest for progress tracking if callback provided
    if (onProgress) {
        return new Promise((resolve, reject) => {
            const xhr = new XMLHttpRequest();

            xhr.upload.addEventListener('progress', (event) => {
                if (event.lengthComputable) {
                    const percentComplete = Math.round((event.loaded / event.total) * 100);
                    onProgress(percentComplete);
                }
            });

            xhr.addEventListener('load', () => {
                if (xhr.status >= 200 && xhr.status < 300) {
                    try {
                        const data = JSON.parse(xhr.responseText);
                        resolve(data);
                    } catch (e) {
                        reject(new ApiError('Invalid response format', xhr.status));
                    }
                } else {
                    let errorMessage = `Upload failed with status ${xhr.status}`;
                    try {
                        const data = JSON.parse(xhr.responseText);
                        if (data.detail) {
                            errorMessage = data.detail;
                        }
                    } catch (e) {
                        // Use default error message
                    }
                    reject(new ApiError(errorMessage, xhr.status));
                }
            });

            xhr.addEventListener('error', () => {
                reject(new ApiError('Network error during upload', 0));
            });

            xhr.addEventListener('abort', () => {
                reject(new ApiError('Upload cancelled', 0));
            });

            xhr.open('POST', `${API_BASE}/projects`);
            xhr.send(formData);
        });
    }

    // Simple fetch for uploads without progress tracking
    return request('/projects', {
        method: 'POST',
        body: formData,
    });
}

/**
 * Get the processing status of a project.
 *
 * @param {string} id - Project UUID
 * @returns {Promise<Object>} - Status object with progress info
 *
 * @example
 * const status = await getProjectStatus('abc-123');
 * console.log(`Status: ${status.status}, Progress: ${status.progress}%`);
 */
export async function getProjectStatus(id) {
    return request(`/projects/${id}/status`);
}

/**
 * Get the audio URL for a project.
 *
 * @param {string} projectId - Project UUID
 * @returns {string} - Full URL to audio stream endpoint
 *
 * @example
 * const audioUrl = getAudioUrl('abc-123');
 * audioElement.src = audioUrl;
 */
export function getAudioUrl(projectId) {
    return `${API_BASE}/audio/${projectId}`;
}

// Default export for convenience
export default {
    getProjects,
    getProject,
    deleteProject,
    uploadProject,
    getProjectStatus,
    getAudioUrl,
    ApiError,
};
