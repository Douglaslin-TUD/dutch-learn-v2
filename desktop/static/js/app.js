/**
 * Main Application for Dutch Language Learning.
 *
 * Handles routing, state management, view rendering, and user interactions.
 */

import { getProjects, getProject, deleteProject, uploadProject, getProjectStatus, getAudioUrl, syncFull, getSyncStatus, toggleDifficult, getDifficultSentences, recordReview, ApiError } from './api.js';
import { AudioPlayer, PLAYBACK_SPEEDS, formatTime } from './audio-player.js';

// ============================================================================
// State Management
// ============================================================================

/**
 * Application state store.
 */
const AppState = {
    /** @type {Array<Object>} */
    projects: [],

    /** @type {Object|null} */
    currentProject: null,

    /** @type {Object|null} */
    selectedSentence: null,

    /** @type {number|null} */
    selectedSentenceIndex: null,

    /** @type {boolean} */
    isPlaying: false,

    /** @type {boolean} */
    isLoading: false,

    /** @type {string|null} */
    error: null,

    /** @type {Set<Function>} */
    _subscribers: new Set(),

    /**
     * Update state and notify subscribers.
     * @param {Object} updates - State updates
     */
    setState(updates) {
        Object.assign(this, updates);
        this._notify();
    },

    /**
     * Subscribe to state changes.
     * @param {Function} callback
     * @returns {Function} - Unsubscribe function
     */
    subscribe(callback) {
        this._subscribers.add(callback);
        return () => this._subscribers.delete(callback);
    },

    /**
     * Notify all subscribers of state change.
     * @private
     */
    _notify() {
        this._subscribers.forEach(cb => cb(this));
    },

    /**
     * Reset state for a clean slate.
     */
    reset() {
        this.currentProject = null;
        this.selectedSentence = null;
        this.selectedSentenceIndex = null;
        this.isPlaying = false;
        this.error = null;
    }
};

// ============================================================================
// Dutch Dictionary
// ============================================================================

/**
 * Dutch-English dictionary loaded from JSON file.
 * @type {Object|null}
 */
let dutchDictionary = null;

/**
 * Load the Dutch-English dictionary from JSON file.
 * @returns {Promise<void>}
 */
async function loadDictionary() {
    try {
        const response = await fetch('/static/data/dictionary.json');
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }
        dutchDictionary = await response.json();
        console.log(`Dutch dictionary loaded: ${Object.keys(dutchDictionary).length} words`);
    } catch (error) {
        console.warn('Failed to load Dutch dictionary:', error.message);
        dutchDictionary = {};
    }
}

/**
 * Look up a word in the Dutch dictionary.
 * @param {string} word - Word to look up
 * @returns {Object|null} - Dictionary entry {pos, en} or null
 */
function lookupWord(word) {
    if (!dutchDictionary || !word) return null;
    const cleanWord = word.toLowerCase().replace(/[.,!?;:'"()\[\]{}]/g, '');
    return dutchDictionary[cleanWord] || null;
}

// ============================================================================
// Router
// ============================================================================

/**
 * Hash-based router for SPA navigation.
 */
const Router = {
    /** @type {Array<{pattern: RegExp, handler: Function}>} */
    routes: [],

    /**
     * Register a route.
     * @param {string} pattern - Route pattern (e.g., '/project/:id')
     * @param {Function} handler - Route handler function
     */
    register(pattern, handler) {
        // Convert pattern to regex
        const regexPattern = pattern
            .replace(/:\w+/g, '([^/]+)')  // Convert :param to capture group
            .replace(/\//g, '\\/');       // Escape slashes

        this.routes.push({
            pattern: new RegExp(`^${regexPattern}$`),
            handler,
        });
    },

    /**
     * Navigate to a hash route.
     * @param {string} path - Route path
     */
    navigate(path) {
        window.location.hash = path;
    },

    /**
     * Handle hash change and route to appropriate handler.
     */
    handleRoute() {
        const hash = window.location.hash.slice(1) || '/';

        for (const route of this.routes) {
            const match = hash.match(route.pattern);
            if (match) {
                const params = match.slice(1);
                route.handler(...params);
                return;
            }
        }

        // Default to home if no route matches
        this.navigate('/');
    },

    /**
     * Initialize router and listen for hash changes.
     */
    init() {
        window.addEventListener('hashchange', () => this.handleRoute());
        this.handleRoute();
    }
};

// ============================================================================
// UI Utilities
// ============================================================================

/**
 * Get the main content container.
 * @returns {HTMLElement}
 */
function getMainContent() {
    return document.getElementById('main-content');
}

/**
 * Get the navigation actions container.
 * @returns {HTMLElement}
 */
function getNavActions() {
    return document.getElementById('nav-actions');
}

/**
 * Show loading overlay.
 * @param {string} message - Loading message
 */
function showLoading(message = 'Loading...') {
    const existing = document.querySelector('.loading-overlay');
    if (existing) existing.remove();

    const template = document.getElementById('loading-template');
    const clone = template.content.cloneNode(true);
    clone.querySelector('.loading-message').textContent = message;
    clone.firstElementChild.classList.add('loading-overlay');
    document.body.appendChild(clone);

    AppState.setState({ isLoading: true });
}

/**
 * Hide loading overlay.
 */
function hideLoading() {
    const overlay = document.querySelector('.loading-overlay');
    if (overlay) overlay.remove();

    AppState.setState({ isLoading: false });
}

/**
 * Show toast notification.
 * @param {string} message - Toast message
 * @param {'success'|'error'|'info'} type - Toast type
 * @param {number} duration - Duration in ms
 */
function showToast(message, type = 'info', duration = 4000) {
    const template = document.getElementById('toast-template');
    const clone = template.content.cloneNode(true);
    const toast = clone.firstElementChild;

    // Set message
    toast.querySelector('.toast-message').textContent = message;

    // Set icon and border color based on type
    const iconContainer = toast.querySelector('.toast-icon');
    const border = toast.querySelector('.bg-white');

    if (type === 'success') {
        border.classList.add('border-green-500');
        iconContainer.innerHTML = `
            <svg class="w-6 h-6 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
            </svg>
        `;
    } else if (type === 'error') {
        border.classList.add('border-red-500');
        iconContainer.innerHTML = `
            <svg class="w-6 h-6 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
        `;
    } else {
        border.classList.add('border-primary-500');
        iconContainer.innerHTML = `
            <svg class="w-6 h-6 text-primary-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
            </svg>
        `;
    }

    // Close button handler
    toast.querySelector('.toast-close').addEventListener('click', () => {
        toast.classList.add('translate-y-full', 'opacity-0');
        setTimeout(() => toast.remove(), 300);
    });

    document.body.appendChild(toast);

    // Animate in
    requestAnimationFrame(() => {
        toast.classList.remove('translate-y-full', 'opacity-0');
    });

    // Auto-dismiss
    setTimeout(() => {
        if (toast.parentNode) {
            toast.classList.add('translate-y-full', 'opacity-0');
            setTimeout(() => toast.remove(), 300);
        }
    }, duration);
}

/**
 * Show confirmation dialog.
 * @param {string} title - Dialog title
 * @param {string} message - Dialog message
 * @returns {Promise<boolean>} - Resolves to true if confirmed
 */
function showConfirmDialog(title, message) {
    return new Promise((resolve) => {
        const template = document.getElementById('confirm-dialog-template');
        const clone = template.content.cloneNode(true);
        const dialog = clone.firstElementChild;

        dialog.querySelector('.dialog-title').textContent = title;
        dialog.querySelector('.dialog-message').textContent = message;

        const cleanup = () => {
            dialog.remove();
        };

        dialog.querySelector('.dialog-cancel').addEventListener('click', () => {
            cleanup();
            resolve(false);
        });

        dialog.querySelector('.dialog-confirm').addEventListener('click', () => {
            cleanup();
            resolve(true);
        });

        // Close on backdrop click
        dialog.addEventListener('click', (e) => {
            if (e.target === dialog) {
                cleanup();
                resolve(false);
            }
        });

        document.body.appendChild(dialog);
    });
}

/**
 * Format date for display.
 * @param {string} isoString - ISO date string
 * @returns {string} - Formatted date
 */
function formatDate(isoString) {
    if (!isoString) return '';
    const date = new Date(isoString);
    return date.toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
    });
}

/**
 * Get status badge HTML.
 * @param {string} status - Project status
 * @returns {string} - HTML string
 */
function getStatusBadge(status) {
    const statusConfig = {
        pending: { bg: 'bg-yellow-100', text: 'text-yellow-800', label: 'Pending' },
        extracting: { bg: 'bg-blue-100', text: 'text-blue-800', label: 'Extracting Audio' },
        transcribing: { bg: 'bg-purple-100', text: 'text-purple-800', label: 'Transcribing' },
        explaining: { bg: 'bg-indigo-100', text: 'text-indigo-800', label: 'Generating Explanations' },
        ready: { bg: 'bg-green-100', text: 'text-green-800', label: 'Ready' },
        error: { bg: 'bg-red-100', text: 'text-red-800', label: 'Error' },
    };

    const config = statusConfig[status] || statusConfig.pending;

    return `
        <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${config.bg} ${config.text}">
            ${config.label}
        </span>
    `;
}

// ============================================================================
// Sync Functions
// ============================================================================

/**
 * Handle sync button click.
 * Performs full bidirectional sync with Google Drive.
 */
async function handleSync() {
    const syncBtn = document.getElementById('sync-btn');
    if (!syncBtn) return;

    // Disable button and show loading state
    syncBtn.disabled = true;
    syncBtn.innerHTML = `
        <div class="animate-spin rounded-full h-5 w-5 border-2 border-gray-500 border-t-transparent mr-2"></div>
        Syncing...
    `;

    try {
        // Check sync status first
        const status = await getSyncStatus();

        if (!status.configured) {
            showToast('Google Drive not configured. Place credentials.json in the project directory.', 'error');
            return;
        }

        // Perform sync
        const result = await syncFull();

        if (result.success) {
            showToast(result.message, 'success');
            // Refresh project list
            renderHomeView();
        } else {
            showToast(result.message, 'error');
            if (result.errors && result.errors.length > 0) {
                console.error('Sync errors:', result.errors);
            }
        }
    } catch (error) {
        showToast(error.message || 'Sync failed', 'error');
    } finally {
        // Reset button state
        if (syncBtn) {
            syncBtn.disabled = false;
            syncBtn.innerHTML = `
                <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
                </svg>
                Sync
            `;
        }
    }
}

// ============================================================================
// Views
// ============================================================================

/**
 * Render Home View - Project List.
 */
async function renderHomeView() {
    AppState.reset();

    // Update navigation
    getNavActions().innerHTML = `
        <button id="sync-btn" class="inline-flex items-center px-4 py-2 text-gray-700 hover:bg-gray-100 rounded-lg transition-colors font-medium mr-2" title="Sync with Google Drive">
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
            </svg>
            Sync
        </button>
        <a href="#/upload" class="inline-flex items-center px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors font-medium shadow-sm">
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"></path>
            </svg>
            New Project
        </a>
    `;

    // Setup sync button handler
    document.getElementById('sync-btn').addEventListener('click', handleSync);

    // Show loading state
    getMainContent().innerHTML = `
        <div class="flex justify-center items-center py-20">
            <div class="animate-spin rounded-full h-10 w-10 border-4 border-primary-500 border-t-transparent"></div>
        </div>
    `;

    try {
        const { projects } = await getProjects();
        AppState.setState({ projects });

        if (projects.length === 0) {
            renderEmptyState();
        } else {
            renderProjectList(projects);
        }

        // Start polling for processing projects
        startStatusPolling();
    } catch (error) {
        showToast(error.message, 'error');
        renderEmptyState();
    }
}

/**
 * Render empty state when no projects exist.
 */
function renderEmptyState() {
    getMainContent().innerHTML = `
        <div class="text-center py-20">
            <svg class="mx-auto h-24 w-24 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"></path>
            </svg>
            <h3 class="mt-6 text-xl font-medium text-gray-900">No projects yet</h3>
            <p class="mt-2 text-gray-500 max-w-sm mx-auto">
                Upload a video or audio file to start learning Dutch with AI-powered explanations.
            </p>
            <a href="#/upload" class="inline-flex items-center mt-6 px-6 py-3 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors font-medium shadow-md">
                <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"></path>
                </svg>
                Upload Your First File
            </a>
        </div>
    `;
}

/**
 * Render project list.
 * @param {Array<Object>} projects
 */
function renderProjectList(projects) {
    const projectCards = projects.map(project => `
        <div class="project-card bg-white rounded-xl shadow-sm border border-gray-200 hover:shadow-md transition-shadow overflow-hidden"
             data-project-id="${project.id}">
            <div class="p-6">
                <div class="flex items-start justify-between">
                    <div class="flex-1 min-w-0">
                        <h3 class="text-lg font-semibold text-gray-900 truncate">${escapeHtml(project.name)}</h3>
                        <p class="mt-1 text-sm text-gray-500">${formatDate(project.created_at)}</p>
                    </div>
                    <div class="ml-4">
                        ${getStatusBadge(project.status)}
                    </div>
                </div>

                ${project.status !== 'ready' && project.status !== 'error' ? `
                    <div class="mt-4">
                        <div class="flex items-center justify-between text-sm text-gray-600 mb-1">
                            <span>Processing...</span>
                            <span class="progress-text">${project.progress}%</span>
                        </div>
                        <div class="w-full bg-gray-200 rounded-full h-2">
                            <div class="progress-bar bg-primary-500 h-2 rounded-full transition-all duration-300"
                                 style="width: ${project.progress}%"></div>
                        </div>
                    </div>
                ` : ''}

                <div class="mt-5 flex items-center justify-between">
                    ${project.status === 'ready' ? `
                        <a href="#/project/${project.id}"
                           class="inline-flex items-center px-4 py-2 bg-primary-50 text-primary-700 rounded-lg hover:bg-primary-100 transition-colors font-medium">
                            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"></path>
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                            </svg>
                            Start Learning
                        </a>
                    ` : project.status === 'error' ? `
                        <span class="text-sm text-red-600">Processing failed</span>
                    ` : `
                        <span class="text-sm text-gray-500">Processing in progress...</span>
                    `}

                    <button class="delete-project-btn p-2 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                            data-project-id="${project.id}"
                            data-project-name="${escapeHtml(project.name)}"
                            title="Delete project">
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path>
                        </svg>
                    </button>
                </div>
            </div>
        </div>
    `).join('');

    getMainContent().innerHTML = `
        <div class="mb-8">
            <h2 class="text-2xl font-bold text-gray-900">Your Projects</h2>
            <p class="mt-1 text-gray-600">Select a project to start learning Dutch</p>
        </div>
        <div class="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
            ${projectCards}
        </div>
    `;

    // Attach delete handlers
    document.querySelectorAll('.delete-project-btn').forEach(btn => {
        btn.addEventListener('click', async (e) => {
            e.stopPropagation();
            const projectId = btn.dataset.projectId;
            const projectName = btn.dataset.projectName;

            const confirmed = await showConfirmDialog(
                'Delete Project',
                `Are you sure you want to delete "${projectName}"? This action cannot be undone.`
            );

            if (confirmed) {
                await handleDeleteProject(projectId);
            }
        });
    });
}

/**
 * Handle project deletion.
 * @param {string} projectId
 */
async function handleDeleteProject(projectId) {
    showLoading('Deleting project...');

    try {
        await deleteProject(projectId);
        showToast('Project deleted successfully', 'success');
        renderHomeView();
    } catch (error) {
        showToast(error.message, 'error');
    } finally {
        hideLoading();
    }
}

/** @type {number|null} */
let statusPollingInterval = null;

/**
 * Start polling for project status updates.
 */
function startStatusPolling() {
    stopStatusPolling();

    const pollStatus = async () => {
        const processingProjects = AppState.projects.filter(
            p => p.status !== 'ready' && p.status !== 'error'
        );

        if (processingProjects.length === 0) {
            stopStatusPolling();
            return;
        }

        for (const project of processingProjects) {
            try {
                const status = await getProjectStatus(project.id);
                updateProjectCard(project.id, status);

                // Update state
                const idx = AppState.projects.findIndex(p => p.id === project.id);
                if (idx !== -1) {
                    AppState.projects[idx] = { ...AppState.projects[idx], ...status };
                }

                // If project is now ready, show notification
                if (status.status === 'ready') {
                    showToast(`"${project.name}" is ready for learning!`, 'success');
                } else if (status.status === 'error') {
                    showToast(`Processing failed for "${project.name}"`, 'error');
                }
            } catch (error) {
                console.error('Status poll error:', error);
            }
        }
    };

    statusPollingInterval = setInterval(pollStatus, 3000);
}

/**
 * Stop status polling.
 */
function stopStatusPolling() {
    if (statusPollingInterval) {
        clearInterval(statusPollingInterval);
        statusPollingInterval = null;
    }
}

/**
 * Update a project card with new status.
 * @param {string} projectId
 * @param {Object} status
 */
function updateProjectCard(projectId, status) {
    const card = document.querySelector(`[data-project-id="${projectId}"]`);
    if (!card) return;

    // Update progress bar if exists
    const progressBar = card.querySelector('.progress-bar');
    const progressText = card.querySelector('.progress-text');

    if (progressBar) {
        progressBar.style.width = `${status.progress}%`;
    }
    if (progressText) {
        progressText.textContent = `${status.progress}%`;
    }

    // If status changed to ready or error, refresh the view
    if (status.status === 'ready' || status.status === 'error') {
        renderHomeView();
    }
}

/**
 * Render Upload View.
 */
function renderUploadView() {
    AppState.reset();
    stopStatusPolling();

    // Update navigation
    getNavActions().innerHTML = `
        <a href="#/" class="inline-flex items-center px-4 py-2 text-gray-700 hover:bg-gray-100 rounded-lg transition-colors font-medium">
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"></path>
            </svg>
            Back to Projects
        </a>
    `;

    getMainContent().innerHTML = `
        <div class="max-w-2xl mx-auto">
            <div class="text-center mb-8">
                <h2 class="text-2xl font-bold text-gray-900">Upload New Project</h2>
                <p class="mt-2 text-gray-600">Upload a video or audio file to create a new learning project</p>
            </div>

            <div class="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
                <form id="upload-form" class="p-8">
                    <!-- Drop Zone -->
                    <div id="drop-zone"
                         class="border-2 border-dashed border-gray-300 rounded-xl p-12 text-center cursor-pointer
                                hover:border-primary-400 hover:bg-primary-50 transition-colors">
                        <input type="file" id="file-input" class="hidden"
                               accept=".mp4,.mkv,.avi,.webm,.mov,.mp3,.wav,.m4a,.flac">

                        <div id="drop-zone-content">
                            <svg class="mx-auto h-16 w-16 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"
                                      d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"></path>
                            </svg>
                            <p class="mt-4 text-lg font-medium text-gray-700">Drop your file here</p>
                            <p class="mt-1 text-gray-500">or click to browse</p>
                            <p class="mt-4 text-sm text-gray-400">
                                Supported formats: MP4, MKV, AVI, WebM, MOV, MP3, WAV, M4A, FLAC
                            </p>
                            <p class="text-sm text-gray-400">Maximum size: 500MB</p>
                        </div>

                        <div id="file-preview" class="hidden">
                            <div class="flex items-center justify-center space-x-4">
                                <svg class="h-12 w-12 text-primary-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                          d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
                                </svg>
                                <div class="text-left">
                                    <p id="file-name" class="font-medium text-gray-900"></p>
                                    <p id="file-size" class="text-sm text-gray-500"></p>
                                </div>
                            </div>
                            <button type="button" id="remove-file-btn"
                                    class="mt-4 text-sm text-red-600 hover:text-red-700 font-medium">
                                Remove file
                            </button>
                        </div>
                    </div>

                    <!-- Progress Bar (hidden initially) -->
                    <div id="upload-progress" class="hidden mt-6">
                        <div class="flex items-center justify-between text-sm text-gray-600 mb-2">
                            <span id="progress-label">Uploading...</span>
                            <span id="progress-percent">0%</span>
                        </div>
                        <div class="w-full bg-gray-200 rounded-full h-3">
                            <div id="progress-bar" class="bg-primary-500 h-3 rounded-full transition-all duration-300" style="width: 0%"></div>
                        </div>
                    </div>

                    <!-- Submit Button -->
                    <button type="submit" id="submit-btn"
                            class="mt-6 w-full py-3 px-4 bg-primary-600 text-white rounded-lg font-medium
                                   hover:bg-primary-700 disabled:bg-gray-300 disabled:cursor-not-allowed
                                   transition-colors flex items-center justify-center"
                            disabled>
                        <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                  d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12"></path>
                        </svg>
                        Upload and Process
                    </button>
                </form>
            </div>

            <!-- Info Card -->
            <div class="mt-6 bg-primary-50 rounded-xl p-6 border border-primary-100">
                <div class="flex">
                    <svg class="h-6 w-6 text-primary-600 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                              d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                    </svg>
                    <div class="ml-4">
                        <h3 class="text-sm font-medium text-primary-900">Processing time</h3>
                        <p class="mt-1 text-sm text-primary-700">
                            Processing typically takes 2-5 minutes depending on the length of your file.
                            You'll be notified when your project is ready for learning.
                        </p>
                    </div>
                </div>
            </div>
        </div>
    `;

    setupUploadHandlers();
}

/**
 * Set up upload form event handlers.
 */
function setupUploadHandlers() {
    const dropZone = document.getElementById('drop-zone');
    const fileInput = document.getElementById('file-input');
    const dropZoneContent = document.getElementById('drop-zone-content');
    const filePreview = document.getElementById('file-preview');
    const fileName = document.getElementById('file-name');
    const fileSize = document.getElementById('file-size');
    const removeFileBtn = document.getElementById('remove-file-btn');
    const submitBtn = document.getElementById('submit-btn');
    const uploadForm = document.getElementById('upload-form');
    const uploadProgress = document.getElementById('upload-progress');
    const progressBar = document.getElementById('progress-bar');
    const progressPercent = document.getElementById('progress-percent');
    const progressLabel = document.getElementById('progress-label');

    /** @type {File|null} */
    let selectedFile = null;

    // Click to open file dialog
    dropZone.addEventListener('click', () => {
        if (!selectedFile) {
            fileInput.click();
        }
    });

    // Drag and drop handlers
    dropZone.addEventListener('dragover', (e) => {
        e.preventDefault();
        dropZone.classList.add('border-primary-500', 'bg-primary-50');
    });

    dropZone.addEventListener('dragleave', () => {
        dropZone.classList.remove('border-primary-500', 'bg-primary-50');
    });

    dropZone.addEventListener('drop', (e) => {
        e.preventDefault();
        dropZone.classList.remove('border-primary-500', 'bg-primary-50');

        const files = e.dataTransfer.files;
        if (files.length > 0) {
            handleFileSelect(files[0]);
        }
    });

    // File input change
    fileInput.addEventListener('change', () => {
        if (fileInput.files.length > 0) {
            handleFileSelect(fileInput.files[0]);
        }
    });

    // Remove file button
    removeFileBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        clearFile();
    });

    // Form submit
    uploadForm.addEventListener('submit', async (e) => {
        e.preventDefault();

        if (!selectedFile) return;

        // Show progress
        uploadProgress.classList.remove('hidden');
        submitBtn.disabled = true;
        submitBtn.innerHTML = `
            <div class="animate-spin rounded-full h-5 w-5 border-2 border-white border-t-transparent mr-2"></div>
            Uploading...
        `;

        try {
            const project = await uploadProject(selectedFile, null, (percent) => {
                progressBar.style.width = `${percent}%`;
                progressPercent.textContent = `${percent}%`;

                if (percent === 100) {
                    progressLabel.textContent = 'Processing...';
                }
            });

            showToast('File uploaded successfully! Processing started.', 'success');

            // Start polling for status and redirect when ready
            pollUntilReady(project.id);
        } catch (error) {
            showToast(error.message, 'error');
            resetUploadUI();
        }
    });

    /**
     * Handle file selection.
     * @param {File} file
     */
    function handleFileSelect(file) {
        // Validate file type
        const validExtensions = ['.mp4', '.mkv', '.avi', '.webm', '.mov', '.mp3', '.wav', '.m4a', '.flac'];
        const ext = '.' + file.name.split('.').pop().toLowerCase();

        if (!validExtensions.includes(ext)) {
            showToast('Invalid file type. Please upload a supported audio or video file.', 'error');
            return;
        }

        // Validate file size (500MB)
        const maxSize = 500 * 1024 * 1024;
        if (file.size > maxSize) {
            showToast('File too large. Maximum size is 500MB.', 'error');
            return;
        }

        selectedFile = file;
        showFilePreview(file);
    }

    /**
     * Show file preview.
     * @param {File} file
     */
    function showFilePreview(file) {
        fileName.textContent = file.name;
        fileSize.textContent = formatFileSize(file.size);
        dropZoneContent.classList.add('hidden');
        filePreview.classList.remove('hidden');
        submitBtn.disabled = false;
    }

    /**
     * Clear selected file.
     */
    function clearFile() {
        selectedFile = null;
        fileInput.value = '';
        dropZoneContent.classList.remove('hidden');
        filePreview.classList.add('hidden');
        submitBtn.disabled = true;
    }

    /**
     * Reset upload UI after error.
     */
    function resetUploadUI() {
        uploadProgress.classList.add('hidden');
        progressBar.style.width = '0%';
        progressPercent.textContent = '0%';
        progressLabel.textContent = 'Uploading...';
        submitBtn.disabled = false;
        submitBtn.innerHTML = `
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                      d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12"></path>
            </svg>
            Upload and Process
        `;
    }

    /**
     * Poll project status until ready or error.
     * @param {string} projectId
     */
    async function pollUntilReady(projectId) {
        const progressLabel = document.getElementById('progress-label');
        const progressBar = document.getElementById('progress-bar');
        const progressPercent = document.getElementById('progress-percent');

        const poll = async () => {
            try {
                const status = await getProjectStatus(projectId);

                progressBar.style.width = `${status.progress}%`;
                progressPercent.textContent = `${status.progress}%`;
                progressLabel.textContent = status.current_stage || 'Processing...';

                if (status.status === 'ready') {
                    showToast('Processing complete! Redirecting to learning view...', 'success');
                    setTimeout(() => {
                        Router.navigate(`/project/${projectId}`);
                    }, 1000);
                } else if (status.status === 'error') {
                    showToast(status.error_message || 'Processing failed', 'error');
                    resetUploadUI();
                } else {
                    setTimeout(poll, 2000);
                }
            } catch (error) {
                showToast('Failed to check status', 'error');
                resetUploadUI();
            }
        };

        poll();
    }
}

/**
 * Format file size to human-readable string.
 * @param {number} bytes
 * @returns {string}
 */
function formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes';

    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));

    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

/**
 * Render Learn View - Study Interface.
 * @param {string} projectId
 */
async function renderLearnView(projectId) {
    AppState.reset();
    stopStatusPolling();

    // Show loading
    getMainContent().innerHTML = `
        <div class="flex justify-center items-center py-20">
            <div class="animate-spin rounded-full h-10 w-10 border-4 border-primary-500 border-t-transparent"></div>
        </div>
    `;

    try {
        const project = await getProject(projectId);

        if (project.status !== 'ready') {
            showToast('This project is still processing. Please wait.', 'info');
            Router.navigate('/');
            return;
        }

        AppState.setState({
            currentProject: project,
            selectedSentence: project.sentences[0] || null,
            selectedSentenceIndex: project.sentences.length > 0 ? 0 : null,
        });

        renderLearnInterface(project);
        setupLearnHandlers(project);
    } catch (error) {
        showToast(error.message, 'error');
        Router.navigate('/');
    }
}

/**
 * Render the learning interface.
 * @param {Object} project
 */
function renderLearnInterface(project) {
    // Update navigation
    getNavActions().innerHTML = `
        <a href="#/" class="inline-flex items-center px-4 py-2 text-gray-700 hover:bg-gray-100 rounded-lg transition-colors font-medium">
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"></path>
            </svg>
            Back to Projects
        </a>
    `;

    const sentencesList = project.sentences.map((sentence, index) => {
        const speakerName = sentence.speaker?.display_name || `Speaker ${sentence.speaker?.label || '?'}`;
        const speakerColor = getSpeakerColor(sentence.speaker?.label);

        return `
        <button class="sentence-item w-full text-left px-4 py-3 hover:bg-gray-50 border-b border-gray-100
                       transition-colors ${index === 0 ? 'bg-primary-50 border-l-4 border-l-primary-500' : ''}"
                data-index="${index}">
            <div class="flex items-start space-x-3">
                <span class="flex-shrink-0 w-8 h-8 rounded-full ${speakerColor} text-white text-sm
                             flex items-center justify-center font-medium sentence-number">
                    ${sentence.speaker?.label || index + 1}
                </span>
                <div class="flex-1 min-w-0">
                    <p class="text-xs text-gray-500 mb-1">${escapeHtml(speakerName)}</p>
                    <p class="text-gray-700 text-sm leading-relaxed sentence-text">${escapeHtml(sentence.text)}</p>
                </div>
                <span class="bookmark-btn flex-shrink-0 p-1 rounded hover:bg-gray-200 transition-colors ${sentence.is_difficult ? 'text-amber-500' : 'text-gray-300'}"
                      data-sentence-id="${sentence.id}" data-index="${index}">
                    <svg class="w-4 h-4" fill="${sentence.is_difficult ? 'currentColor' : 'none'}" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z"></path>
                    </svg>
                </span>
            </div>
        </button>
    `}).join('');

    const firstSentence = project.sentences[0];

    getMainContent().innerHTML = `
        <div class="flex flex-col h-[calc(100vh-10rem)]">
            <!-- Audio Player Bar -->
            <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-4 mb-4">
                <div class="flex items-center space-x-4">
                    <!-- Play/Pause Button -->
                    <button id="play-btn" class="flex-shrink-0 w-12 h-12 rounded-full bg-primary-600 text-white
                                                 hover:bg-primary-700 transition-colors flex items-center justify-center shadow-md">
                        <svg id="play-icon" class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                  d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"></path>
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                        </svg>
                        <svg id="pause-icon" class="w-6 h-6 hidden" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 9v6m4-6v6m7-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                        </svg>
                    </button>

                    <!-- Progress Bar -->
                    <div class="flex-1 flex items-center space-x-3">
                        <span id="current-time" class="text-sm text-gray-600 w-14 text-right font-mono">0:00</span>
                        <div id="progress-container" class="flex-1 h-2 bg-gray-200 rounded-full cursor-pointer relative group">
                            <div id="audio-progress" class="h-full bg-primary-500 rounded-full transition-all" style="width: 0%"></div>
                            <div id="progress-handle" class="absolute top-1/2 -translate-y-1/2 w-4 h-4 bg-primary-600 rounded-full
                                                            shadow-md opacity-0 group-hover:opacity-100 transition-opacity"
                                 style="left: 0%"></div>
                        </div>
                        <span id="total-time" class="text-sm text-gray-600 w-14 font-mono">0:00</span>
                    </div>

                    <!-- Loop Button -->
                    <button id="loop-btn" class="flex-shrink-0 p-2 rounded-lg text-gray-500 hover:bg-gray-100 transition-colors"
                            title="Loop current sentence">
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                  d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
                        </svg>
                    </button>

                    <!-- Speed Control -->
                    <div class="relative">
                        <button id="speed-btn" class="flex-shrink-0 px-3 py-2 rounded-lg text-gray-600 hover:bg-gray-100
                                                       transition-colors text-sm font-medium">
                            1x
                        </button>
                        <div id="speed-menu" class="hidden absolute bottom-full right-0 mb-2 bg-white rounded-lg shadow-lg border
                                                    border-gray-200 py-1 min-w-[80px]">
                            ${PLAYBACK_SPEEDS.map(speed => `
                                <button class="speed-option w-full px-4 py-2 text-left text-sm hover:bg-gray-100
                                               transition-colors ${speed === 1 ? 'text-primary-600 font-medium' : 'text-gray-700'}"
                                        data-speed="${speed}">
                                    ${speed}x
                                </button>
                            `).join('')}
                        </div>
                    </div>
                </div>

                <!-- Hidden audio element -->
                <audio id="audio-element" preload="auto"></audio>
            </div>

            <!-- Main Content Area -->
            <div class="flex-1 flex gap-4 min-h-0">
                <!-- Left Panel - Sentence List -->
                <div class="w-1/2 bg-white rounded-xl shadow-sm border border-gray-200 flex flex-col">
                    <div class="p-4 border-b border-gray-200 flex-shrink-0">
                        <div class="flex items-center justify-between">
                            <div>
                                <h3 class="text-lg font-semibold text-gray-900">${escapeHtml(project.name)}</h3>
                                <p class="text-sm text-gray-500">${project.sentences.length} sentences</p>
                            </div>
                            <a href="#/project/${project.id}/review"
                               class="inline-flex items-center px-3 py-1.5 text-sm font-medium text-amber-700 bg-amber-50 hover:bg-amber-100 rounded-lg transition-colors border border-amber-200"
                               title="Review difficult sentences">
                                <svg class="w-4 h-4 mr-1.5" fill="currentColor" viewBox="0 0 24 24">
                                    <path d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z"></path>
                                </svg>
                                Review
                            </a>
                        </div>
                    </div>

                    <!-- Speaker Panel -->
                    ${(project.speakers && project.speakers.length > 0) ? `
                    <div class="p-4 border-b border-gray-200 flex-shrink-0">
                        <h4 class="text-sm font-semibold text-gray-700 mb-3">Speakers</h4>
                        <div id="speakers-list" class="flex flex-wrap gap-2">
                            ${project.speakers.map(speaker => `
                                <div class="speaker-chip flex items-center gap-2 px-3 py-1.5 rounded-full ${getSpeakerColor(speaker.label)} bg-opacity-10 border border-current"
                                     data-speaker-id="${speaker.id}">
                                    <span class="w-5 h-5 rounded-full ${getSpeakerColor(speaker.label)} text-white text-xs flex items-center justify-center">
                                        ${speaker.label}
                                    </span>
                                    <input type="text"
                                           class="speaker-name-input bg-transparent border-none text-sm text-gray-700 w-24 focus:outline-none focus:ring-1 focus:ring-primary-300 rounded"
                                           value="${escapeHtml(speaker.display_name || `Speaker ${speaker.label}`)}"
                                           data-speaker-id="${speaker.id}"
                                           data-original="${escapeHtml(speaker.display_name || '')}">
                                    ${speaker.is_manual ? '<span class="text-xs text-gray-400">&#10003;</span>' : ''}
                                </div>
                            `).join('')}
                        </div>
                    </div>
                    ` : ''}

                    <div id="sentences-list" class="flex-1 overflow-y-auto">
                        ${sentencesList}
                    </div>
                </div>

                <!-- Right Panel - Details -->
                <div class="w-1/2 bg-white rounded-xl shadow-sm border border-gray-200 flex flex-col">
                    <div class="p-4 border-b border-gray-200 flex-shrink-0">
                        <h3 class="text-lg font-semibold text-gray-900">Sentence Details</h3>
                    </div>
                    <div id="detail-panel" class="flex-1 overflow-y-auto p-4">
                        ${firstSentence ? renderSentenceDetail(firstSentence) : '<p class="text-gray-500">Select a sentence to see details</p>'}
                    </div>
                </div>
            </div>

            <!-- Keyboard Shortcuts Help -->
            <div class="mt-4 text-center text-sm text-gray-500">
                <span class="inline-flex items-center px-2 py-1 bg-gray-100 rounded text-xs font-mono mr-2">Space</span> Play/Pause
                <span class="mx-4">|</span>
                <span class="inline-flex items-center px-2 py-1 bg-gray-100 rounded text-xs font-mono mr-2">Left/Right</span> Prev/Next Sentence
                <span class="mx-4">|</span>
                <span class="inline-flex items-center px-2 py-1 bg-gray-100 rounded text-xs font-mono mr-2">L</span> Toggle Loop
            </div>
        </div>
    `;
}

/**
 * Create hoverable words from sentence text.
 * Prioritizes GPT keywords, then dictionary lookup, then no definition.
 * @param {string} text - Original sentence text
 * @param {Array} keywords - Keywords with meanings from GPT
 * @returns {string} - HTML with hoverable words
 */
function createHoverableText(text, keywords) {
    if (!text) return '';

    // Create a map of GPT keywords to their meanings
    const gptWordMap = new Map();
    if (keywords && keywords.length > 0) {
        keywords.forEach(kw => {
            const word = kw.word.toLowerCase();
            gptWordMap.set(word, {
                word: kw.word,
                meaning_nl: kw.meaning_nl,
                meaning_en: kw.meaning_en
            });
        });
    }

    // Split text into words while preserving punctuation
    const words = text.split(/(\s+|[.,!?;:'"()[\]{}])/);

    return words.map(word => {
        if (!word.trim() || /^[\s.,!?;:'"()[\]{}]+$/.test(word)) {
            return escapeHtml(word);
        }

        const cleanWord = word.toLowerCase().replace(/[.,!?;:'"()[\]{}]/g, '');
        const gptMeaning = gptWordMap.get(cleanWord);

        // Priority 1: GPT keyword (blue dotted border)
        if (gptMeaning) {
            return `<span class="hoverable-word cursor-help border-b-2 border-dotted border-primary-400 hover:bg-primary-100 transition-colors relative"
                         data-source="gpt"
                         data-word="${escapeHtml(gptMeaning.word)}"
                         data-meaning-nl="${escapeHtml(gptMeaning.meaning_nl)}"
                         data-meaning-en="${escapeHtml(gptMeaning.meaning_en)}">${escapeHtml(word)}</span>`;
        }

        // Priority 2: Dictionary lookup (gray dotted border)
        const dictEntry = lookupWord(cleanWord);
        if (dictEntry) {
            return `<span class="hoverable-word cursor-help border-b border-dotted border-gray-400 hover:bg-gray-100 transition-colors relative"
                         data-source="dictionary"
                         data-word="${escapeHtml(word)}"
                         data-dict-pos="${escapeHtml(dictEntry.pos || '')}"
                         data-dict-en="${escapeHtml(dictEntry.en)}">${escapeHtml(word)}</span>`;
        }

        // Priority 3: No definition found
        return `<span class="hoverable-word cursor-help hover:bg-gray-100 transition-colors"
                     data-source="none"
                     data-word="${escapeHtml(word)}">${escapeHtml(word)}</span>`;
    }).join('');
}

/**
 * Render sentence detail panel content.
 * @param {Object} sentence
 * @returns {string}
 */
function renderSentenceDetail(sentence) {
    if (!sentence) {
        return '<p class="text-gray-500 text-center py-10">Select a sentence to see details</p>';
    }

    const keywordsList = sentence.keywords && sentence.keywords.length > 0
        ? sentence.keywords.map(kw => `
            <div class="flex items-start space-x-3 p-3 bg-gray-50 rounded-lg">
                <div class="flex-shrink-0 w-2 h-2 bg-primary-500 rounded-full mt-2"></div>
                <div>
                    <p class="font-semibold text-gray-900">${escapeHtml(kw.word)}</p>
                    <p class="text-sm text-gray-600 mt-0.5">${escapeHtml(kw.meaning_nl)}</p>
                    <p class="text-sm text-gray-500 mt-0.5">${escapeHtml(kw.meaning_en)}</p>
                </div>
            </div>
        `).join('')
        : '<p class="text-gray-500 text-sm">No keywords extracted for this sentence.</p>';

    // Create hoverable text for the Dutch sentence
    const hoverableText = createHoverableText(sentence.text, sentence.keywords);

    return `
        <div class="space-y-6">
            <!-- Original Sentence with Hoverable Words -->
            <div class="bg-primary-50 rounded-lg p-4 border border-primary-100 relative">
                <p id="sentence-text" class="text-lg text-primary-900 font-medium leading-relaxed">${hoverableText}</p>
                <p class="text-sm text-primary-600 mt-2">
                    ${formatTime(sentence.start_time)} - ${formatTime(sentence.end_time)}
                </p>
                <!-- Tooltip container -->
                <div id="word-tooltip" class="hidden absolute z-50 bg-gray-900 text-white text-sm rounded-lg shadow-lg p-3 max-w-xs">
                    <p id="tooltip-word" class="font-semibold text-primary-300"></p>
                    <p id="tooltip-nl" class="mt-1 text-gray-300"></p>
                    <p id="tooltip-en" class="mt-0.5 text-gray-400"></p>
                </div>
            </div>

            <!-- English Translation -->
            ${sentence.translation_en ? `
            <div>
                <h4 class="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3 flex items-center">
                    <span class="w-6 h-6 bg-green-100 text-green-600 rounded flex items-center justify-center text-xs mr-2">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5h12M9 3v2m1.048 9.5A18.022 18.022 0 016.412 9m6.088 9h7M11 21l5-10 5 10M12.751 5C11.783 10.77 8.07 15.61 3 18.129"></path>
                        </svg>
                    </span>
                    Translation
                </h4>
                <div class="bg-green-50 rounded-lg p-4 border border-green-100">
                    <p class="text-gray-800 leading-relaxed font-medium">
                        ${escapeHtml(sentence.translation_en)}
                    </p>
                </div>
            </div>
            ` : ''}

            <!-- Dutch Explanation -->
            <div>
                <h4 class="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3 flex items-center">
                    <span class="w-6 h-6 bg-orange-100 text-orange-600 rounded flex items-center justify-center text-xs mr-2">NL</span>
                    Nederlands
                </h4>
                <div class="bg-orange-50 rounded-lg p-4 border border-orange-100">
                    <p class="text-gray-800 leading-relaxed">
                        ${sentence.explanation_nl ? escapeHtml(sentence.explanation_nl) : '<span class="text-gray-400 italic">No explanation available</span>'}
                    </p>
                </div>
            </div>

            <!-- English Explanation -->
            <div>
                <h4 class="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3 flex items-center">
                    <span class="w-6 h-6 bg-blue-100 text-blue-600 rounded flex items-center justify-center text-xs mr-2">EN</span>
                    English
                </h4>
                <div class="bg-blue-50 rounded-lg p-4 border border-blue-100">
                    <p class="text-gray-800 leading-relaxed">
                        ${sentence.explanation_en ? escapeHtml(sentence.explanation_en) : '<span class="text-gray-400 italic">No explanation available</span>'}
                    </p>
                </div>
            </div>

            <!-- Vocabulary -->
            <div>
                <h4 class="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3 flex items-center">
                    <svg class="w-5 h-5 mr-2 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                              d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"></path>
                    </svg>
                    Vocabulary
                </h4>
                <div class="space-y-2">
                    ${keywordsList}
                </div>
            </div>
        </div>
    `;
}

/**
 * Set up event handlers for the learn view.
 * @param {Object} project
 */
function setupLearnHandlers(project) {
    const audioElement = document.getElementById('audio-element');
    const playBtn = document.getElementById('play-btn');
    const playIcon = document.getElementById('play-icon');
    const pauseIcon = document.getElementById('pause-icon');
    const currentTimeEl = document.getElementById('current-time');
    const totalTimeEl = document.getElementById('total-time');
    const audioProgress = document.getElementById('audio-progress');
    const progressHandle = document.getElementById('progress-handle');
    const progressContainer = document.getElementById('progress-container');
    const loopBtn = document.getElementById('loop-btn');
    const speedBtn = document.getElementById('speed-btn');
    const speedMenu = document.getElementById('speed-menu');
    const sentencesList = document.getElementById('sentences-list');
    const detailPanel = document.getElementById('detail-panel');

    // Initialize audio player
    const player = new AudioPlayer(audioElement);
    window.audioPlayer = player; // For debugging

    // Load audio
    const audioUrl = getAudioUrl(project.id);
    player.load(audioUrl).then(duration => {
        totalTimeEl.textContent = formatTime(duration);
    }).catch(error => {
        showToast('Failed to load audio: ' + error.message, 'error');
    });

    // Time update handler
    player.onTimeUpdate((currentTime, duration) => {
        currentTimeEl.textContent = formatTime(currentTime);
        if (duration > 0) {
            const percent = (currentTime / duration) * 100;
            audioProgress.style.width = `${percent}%`;
            progressHandle.style.left = `${percent}%`;
        }
    });

    // Play state change handler
    player.onPlayStateChange((isPlaying) => {
        AppState.setState({ isPlaying });
        if (isPlaying) {
            playIcon.classList.add('hidden');
            pauseIcon.classList.remove('hidden');
        } else {
            playIcon.classList.remove('hidden');
            pauseIcon.classList.add('hidden');
        }
    });

    // Segment end handler - auto-advance to next sentence
    player.onSegmentEnd(() => {
        // Optionally auto-advance to next sentence
        // Uncomment below to enable:
        // if (AppState.selectedSentenceIndex < project.sentences.length - 1) {
        //     selectSentence(AppState.selectedSentenceIndex + 1);
        // }
    });

    // Play button click
    playBtn.addEventListener('click', () => {
        if (player.isPlaying()) {
            player.pause();
        } else {
            const sentence = AppState.selectedSentence;
            if (sentence) {
                player.playSegment(sentence.start_time, sentence.end_time);
            }
        }
    });

    // Progress bar click for seeking
    progressContainer.addEventListener('click', (e) => {
        const rect = progressContainer.getBoundingClientRect();
        const percent = (e.clientX - rect.left) / rect.width;
        const duration = player.getDuration();
        if (duration > 0) {
            player.seek(percent * duration);
        }
    });

    // Loop button
    loopBtn.addEventListener('click', () => {
        const isLooping = player.toggleLoop();
        if (isLooping) {
            loopBtn.classList.add('bg-primary-100', 'text-primary-600');
        } else {
            loopBtn.classList.remove('bg-primary-100', 'text-primary-600');
        }
        showToast(isLooping ? 'Loop enabled' : 'Loop disabled', 'info', 1500);
    });

    // Speed button and menu
    speedBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        speedMenu.classList.toggle('hidden');
    });

    document.addEventListener('click', () => {
        speedMenu.classList.add('hidden');
    });

    speedMenu.querySelectorAll('.speed-option').forEach(option => {
        option.addEventListener('click', (e) => {
            e.stopPropagation();
            const speed = parseFloat(option.dataset.speed);
            player.setPlaybackRate(speed);
            speedBtn.textContent = `${speed}x`;

            // Update active state
            speedMenu.querySelectorAll('.speed-option').forEach(opt => {
                opt.classList.remove('text-primary-600', 'font-medium');
                opt.classList.add('text-gray-700');
            });
            option.classList.add('text-primary-600', 'font-medium');
            option.classList.remove('text-gray-700');

            speedMenu.classList.add('hidden');
        });
    });

    // Bookmark click handler
    sentencesList.addEventListener('click', async (e) => {
        const bookmarkBtn = e.target.closest('.bookmark-btn');
        if (bookmarkBtn) {
            e.stopPropagation();
            const sentenceId = bookmarkBtn.dataset.sentenceId;
            const idx = parseInt(bookmarkBtn.dataset.index, 10);
            try {
                const result = await toggleDifficult(project.id, sentenceId);
                project.sentences[idx].is_difficult = result.is_difficult;
                const svg = bookmarkBtn.querySelector('svg');
                bookmarkBtn.classList.toggle('text-amber-500', result.is_difficult);
                bookmarkBtn.classList.toggle('text-gray-300', !result.is_difficult);
                svg.setAttribute('fill', result.is_difficult ? 'currentColor' : 'none');
            } catch (err) {
                showToast('Failed to toggle bookmark', 'error');
            }
            return;
        }

        // Sentence list click handler
        const sentenceItem = e.target.closest('.sentence-item');
        if (sentenceItem) {
            const index = parseInt(sentenceItem.dataset.index, 10);
            selectSentence(index);
        }
    });

    // Speaker name editing
    document.querySelectorAll('.speaker-name-input').forEach(input => {
        input.addEventListener('blur', async (e) => {
            const speakerId = e.target.dataset.speakerId;
            const newName = e.target.value.trim();
            const originalName = e.target.dataset.original;

            if (newName && newName !== originalName) {
                try {
                    const response = await fetch(`/api/projects/${project.id}/speakers/${speakerId}`, {
                        method: 'PUT',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ name: newName }),
                    });

                    if (response.ok) {
                        e.target.dataset.original = newName;
                        showToast('Speaker name updated', 'success', 2000);
                        // Refresh to update sentence list
                        renderLearnView(project.id);
                    }
                } catch (error) {
                    showToast('Failed to update speaker name', 'error');
                    e.target.value = originalName;
                }
            }
        });

        input.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') {
                e.target.blur();
            }
        });
    });

    /**
     * Select a sentence by index.
     * @param {number} index
     */
    function selectSentence(index) {
        if (index < 0 || index >= project.sentences.length) return;

        const sentence = project.sentences[index];
        AppState.setState({
            selectedSentence: sentence,
            selectedSentenceIndex: index,
        });

        // Update sentence list styling
        sentencesList.querySelectorAll('.sentence-item').forEach((item, i) => {
            if (i === index) {
                item.classList.add('bg-primary-50', 'border-l-4', 'border-l-primary-500');
                // Scroll into view
                item.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
            } else {
                item.classList.remove('bg-primary-50', 'border-l-4', 'border-l-primary-500');
            }
        });

        // Update detail panel
        detailPanel.innerHTML = renderSentenceDetail(sentence);

        // Setup tooltip handlers for hoverable words
        setupWordTooltips();

        // Play the segment
        player.playSegment(sentence.start_time, sentence.end_time);
    }

    /**
     * Setup tooltip handlers for hoverable words.
     * Displays different content based on data-source attribute:
     * - "gpt": Full NL + EN definitions from GPT
     * - "dictionary": Part of speech + EN translation from dictionary
     * - "none": No definition found message
     */
    function setupWordTooltips() {
        const tooltip = document.getElementById('word-tooltip');
        const tooltipWord = document.getElementById('tooltip-word');
        const tooltipNl = document.getElementById('tooltip-nl');
        const tooltipEn = document.getElementById('tooltip-en');

        if (!tooltip) return;

        const hoverableWords = document.querySelectorAll('.hoverable-word');

        hoverableWords.forEach(wordEl => {
            wordEl.addEventListener('mouseenter', (e) => {
                const word = wordEl.dataset.word;
                const source = wordEl.dataset.source;

                tooltipWord.textContent = word;

                if (source === 'gpt') {
                    // GPT keyword: show full NL + EN definitions
                    const meaningNl = wordEl.dataset.meaningNl;
                    const meaningEn = wordEl.dataset.meaningEn;
                    tooltipNl.textContent = meaningNl;
                    tooltipEn.textContent = meaningEn;
                    tooltipNl.classList.remove('hidden');
                    tooltipEn.classList.remove('hidden');
                } else if (source === 'dictionary') {
                    // Dictionary word: show part of speech + EN translation
                    const pos = wordEl.dataset.dictPos;
                    const en = wordEl.dataset.dictEn;
                    if (pos) {
                        tooltipNl.textContent = `[${pos}]`;
                        tooltipNl.classList.remove('hidden');
                    } else {
                        tooltipNl.classList.add('hidden');
                    }
                    tooltipEn.textContent = en;
                    tooltipEn.classList.remove('hidden');
                } else {
                    // No definition found
                    tooltipNl.textContent = 'No definition found';
                    tooltipEn.textContent = '';
                    tooltipNl.classList.remove('hidden');
                    tooltipEn.classList.add('hidden');
                }

                // Position tooltip near the word
                const rect = wordEl.getBoundingClientRect();
                const parentRect = wordEl.closest('.bg-primary-50').getBoundingClientRect();

                tooltip.style.left = `${rect.left - parentRect.left}px`;
                tooltip.style.top = `${rect.bottom - parentRect.top + 8}px`;
                tooltip.classList.remove('hidden');
            });

            wordEl.addEventListener('mouseleave', () => {
                tooltip.classList.add('hidden');
            });
        });
    }

    // Keyboard shortcuts
    document.addEventListener('keydown', handleKeyboard);

    /**
     * Handle keyboard shortcuts.
     * @param {KeyboardEvent} e
     */
    function handleKeyboard(e) {
        // Ignore if typing in an input
        if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') {
            return;
        }

        switch (e.code) {
            case 'Space':
                e.preventDefault();
                if (player.isPlaying()) {
                    player.pause();
                } else {
                    const sentence = AppState.selectedSentence;
                    if (sentence) {
                        player.playSegment(sentence.start_time, sentence.end_time);
                    }
                }
                break;

            case 'ArrowLeft':
                e.preventDefault();
                if (AppState.selectedSentenceIndex > 0) {
                    selectSentence(AppState.selectedSentenceIndex - 1);
                }
                break;

            case 'ArrowRight':
                e.preventDefault();
                if (AppState.selectedSentenceIndex < project.sentences.length - 1) {
                    selectSentence(AppState.selectedSentenceIndex + 1);
                }
                break;

            case 'KeyL':
                e.preventDefault();
                loopBtn.click();
                break;
        }
    }

    // Initialize tooltips for the first sentence
    setupWordTooltips();

    // Cleanup on view change
    const cleanup = () => {
        document.removeEventListener('keydown', handleKeyboard);
        player.destroy();
    };

    // Store cleanup function
    window._learnViewCleanup = cleanup;
}

/**
 * Escape HTML to prevent XSS.
 * @param {string} str
 * @returns {string}
 */
function escapeHtml(str) {
    if (!str) return '';
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
}

/**
 * Get color class for speaker label.
 * @param {string} label - Speaker label (A, B, C...)
 * @returns {string} - Tailwind color class
 */
function getSpeakerColor(label) {
    const colors = {
        'A': 'bg-blue-500',
        'B': 'bg-green-500',
        'C': 'bg-purple-500',
        'D': 'bg-orange-500',
        'E': 'bg-pink-500',
        'F': 'bg-teal-500',
    };
    return colors[label] || 'bg-gray-500';
}

// ============================================================================
// Review Mode
// ============================================================================

/**
 * Render the review view for difficult sentences.
 */
async function renderReviewView(projectId) {
    // Clean up previous view
    if (window._learnViewCleanup) {
        window._learnViewCleanup();
        window._learnViewCleanup = null;
    }

    showLoading('Loading difficult sentences...');

    try {
        const [project, difficultData] = await Promise.all([
            getProject(projectId),
            getDifficultSentences(projectId),
        ]);

        hideLoading();

        const sentences = difficultData.sentences;
        if (!sentences || sentences.length === 0) {
            getNavActions().innerHTML = `
                <a href="#/project/${projectId}" class="inline-flex items-center px-4 py-2 text-gray-700 hover:bg-gray-100 rounded-lg transition-colors font-medium">
                    <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"></path>
                    </svg>
                    Back to Project
                </a>
            `;
            getMainContent().innerHTML = `
                <div class="flex flex-col items-center justify-center h-[calc(100vh-12rem)]">
                    <svg class="w-16 h-16 text-gray-300 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z"></path>
                    </svg>
                    <h2 class="text-xl font-semibold text-gray-600 mb-2">No difficult sentences</h2>
                    <p class="text-gray-500 mb-6">Bookmark sentences with the bookmark icon to review them here.</p>
                    <a href="#/project/${projectId}" class="px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors">Back to Project</a>
                </div>
            `;
            return;
        }

        renderReviewInterface(project, sentences);
        setupReviewHandlers(project, sentences);

    } catch (error) {
        hideLoading();
        showToast('Failed to load review: ' + error.message, 'error');
        Router.navigate(`/project/${projectId}`);
    }
}

/**
 * Render the review interface.
 */
function renderReviewInterface(project, sentences) {
    getNavActions().innerHTML = `
        <a href="#/project/${project.id}" class="inline-flex items-center px-4 py-2 text-gray-700 hover:bg-gray-100 rounded-lg transition-colors font-medium">
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"></path>
            </svg>
            Back to Project
        </a>
    `;

    getMainContent().innerHTML = `
        <div class="flex flex-col items-center h-[calc(100vh-10rem)]">
            <!-- Progress -->
            <div class="w-full max-w-2xl mb-6">
                <div class="flex items-center justify-between mb-2">
                    <h2 class="text-lg font-semibold text-gray-900">Review Mode</h2>
                    <span id="review-progress" class="text-sm text-gray-500">1 / ${sentences.length}</span>
                </div>
                <div class="w-full h-2 bg-gray-200 rounded-full">
                    <div id="review-progress-bar" class="h-full bg-amber-500 rounded-full transition-all" style="width: ${100 / sentences.length}%"></div>
                </div>
            </div>

            <!-- Card -->
            <div id="review-card" class="w-full max-w-2xl flex-1 bg-white rounded-xl shadow-lg border border-gray-200 flex flex-col overflow-hidden">
                <!-- Audio controls -->
                <div class="p-4 border-b border-gray-200 flex items-center space-x-4">
                    <button id="review-play-btn" class="w-12 h-12 rounded-full bg-primary-600 text-white hover:bg-primary-700 transition-colors flex items-center justify-center shadow-md">
                        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"></path>
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                        </svg>
                    </button>
                    <div class="flex-1">
                        <p class="text-sm text-gray-500">Listen and try to understand</p>
                    </div>
                    <audio id="review-audio" preload="auto"></audio>
                </div>

                <!-- Content area -->
                <div id="review-content" class="flex-1 flex items-center justify-center p-8 cursor-pointer" title="Click to reveal">
                    <div id="review-overlay" class="text-center">
                        <svg class="w-12 h-12 text-gray-300 mx-auto mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path>
                        </svg>
                        <p class="text-gray-400 text-lg">Tap to reveal</p>
                    </div>
                    <div id="review-text" class="hidden w-full space-y-4"></div>
                </div>

                <!-- Navigation -->
                <div class="p-4 border-t border-gray-200 flex justify-between">
                    <button id="review-prev" class="px-4 py-2 text-gray-600 hover:bg-gray-100 rounded-lg transition-colors" disabled>Previous</button>
                    <button id="review-next" class="px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors">Next</button>
                </div>
            </div>
        </div>
    `;
}

/**
 * Set up event handlers for review mode.
 */
function setupReviewHandlers(project, sentences) {
    const audioElement = document.getElementById('review-audio');
    const playBtn = document.getElementById('review-play-btn');
    const content = document.getElementById('review-content');
    const overlay = document.getElementById('review-overlay');
    const textDiv = document.getElementById('review-text');
    const prevBtn = document.getElementById('review-prev');
    const nextBtn = document.getElementById('review-next');
    const progressEl = document.getElementById('review-progress');
    const progressBar = document.getElementById('review-progress-bar');

    const player = new AudioPlayer(audioElement);
    const audioUrl = getAudioUrl(project.id);
    player.load(audioUrl);

    let currentIndex = 0;
    let revealed = false;
    let autoRevealTimer = null;

    function showSentence(index) {
        currentIndex = index;
        revealed = false;
        const sentence = sentences[index];

        // Update progress
        progressEl.textContent = `${index + 1} / ${sentences.length}`;
        progressBar.style.width = `${((index + 1) / sentences.length) * 100}%`;

        // Reset content
        overlay.classList.remove('hidden');
        textDiv.classList.add('hidden');

        // Update navigation
        prevBtn.disabled = index === 0;
        nextBtn.textContent = index === sentences.length - 1 ? 'Finish' : 'Next';

        // Play audio segment
        player.playSegment(sentence.start_time, sentence.end_time);

        // Start auto-reveal timer
        clearTimeout(autoRevealTimer);
        autoRevealTimer = setTimeout(() => {
            if (!revealed) revealText();
        }, 5000);
    }

    function revealText() {
        if (revealed) return;
        revealed = true;
        clearTimeout(autoRevealTimer);

        const sentence = sentences[currentIndex];
        overlay.classList.add('hidden');
        textDiv.classList.remove('hidden');

        const speakerName = sentence.speaker?.display_name || `Speaker ${sentence.speaker?.label || '?'}`;
        textDiv.innerHTML = `
            <div class="bg-primary-50 rounded-lg p-4 border border-primary-100">
                <p class="text-xs text-gray-500 mb-1">${escapeHtml(speakerName)}</p>
                <p class="text-lg text-primary-900 font-medium leading-relaxed">${escapeHtml(sentence.text)}</p>
            </div>
            ${sentence.translation_en ? `
            <div class="bg-green-50 rounded-lg p-4 border border-green-100">
                <p class="text-gray-800 leading-relaxed">${escapeHtml(sentence.translation_en)}</p>
            </div>
            ` : ''}
            ${sentence.explanation_en ? `
            <div class="bg-blue-50 rounded-lg p-3 border border-blue-100">
                <p class="text-sm text-gray-700">${escapeHtml(sentence.explanation_en)}</p>
            </div>
            ` : ''}
        `;

        // Record review
        recordReview(project.id, sentence.id).catch(() => {});
    }

    // Play button
    playBtn.addEventListener('click', () => {
        const sentence = sentences[currentIndex];
        player.playSegment(sentence.start_time, sentence.end_time);
    });

    // Click to reveal
    content.addEventListener('click', () => {
        if (!revealed) revealText();
    });

    // Navigation
    nextBtn.addEventListener('click', () => {
        if (currentIndex < sentences.length - 1) {
            showSentence(currentIndex + 1);
        } else {
            // Show completion summary
            getMainContent().innerHTML = `
                <div class="flex flex-col items-center justify-center h-[calc(100vh-12rem)]">
                    <svg class="w-16 h-16 text-amber-500 mb-4" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z"></path>
                    </svg>
                    <h2 class="text-xl font-semibold text-gray-900 mb-2">Review Complete!</h2>
                    <p class="text-gray-500 mb-6">You reviewed ${sentences.length} difficult sentence${sentences.length > 1 ? 's' : ''}.</p>
                    <div class="flex space-x-4">
                        <a href="#/project/${project.id}/review" class="px-4 py-2 bg-amber-500 text-white rounded-lg hover:bg-amber-600 transition-colors">Review Again</a>
                        <a href="#/project/${project.id}" class="px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors">Back to Project</a>
                    </div>
                </div>
            `;
            player.destroy();
        }
    });

    prevBtn.addEventListener('click', () => {
        if (currentIndex > 0) {
            showSentence(currentIndex - 1);
        }
    });

    // Keyboard shortcuts
    function handleReviewKeyboard(e) {
        if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return;
        switch (e.code) {
            case 'Space':
                e.preventDefault();
                if (!revealed) {
                    revealText();
                } else {
                    const sentence = sentences[currentIndex];
                    player.playSegment(sentence.start_time, sentence.end_time);
                }
                break;
            case 'ArrowRight':
            case 'Enter':
                e.preventDefault();
                nextBtn.click();
                break;
            case 'ArrowLeft':
                e.preventDefault();
                prevBtn.click();
                break;
        }
    }

    document.addEventListener('keydown', handleReviewKeyboard);

    // Start with first sentence
    showSentence(0);

    // Cleanup
    window._learnViewCleanup = () => {
        document.removeEventListener('keydown', handleReviewKeyboard);
        clearTimeout(autoRevealTimer);
        player.destroy();
    };
}

// ============================================================================
// Application Initialization
// ============================================================================

/**
 * Initialize the application.
 */
async function init() {
    // Load the Dutch-English dictionary
    await loadDictionary();

    // Register routes
    Router.register('/', renderHomeView);
    Router.register('/upload', renderUploadView);
    Router.register('/project/:id/review', renderReviewView);
    Router.register('/project/:id', renderLearnView);

    // Clean up previous view handlers when navigating
    window.addEventListener('hashchange', () => {
        if (window._learnViewCleanup) {
            window._learnViewCleanup();
            window._learnViewCleanup = null;
        }
    });

    // Initialize router
    Router.init();

    console.log('Dutch Language Learning App initialized');
}

// Start the app when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
} else {
    init();
}

// Export for testing/debugging
export { AppState, Router };
