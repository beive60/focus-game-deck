/**
 * Focus Game Deck - Simple Internationalization Script with Dark Theme Support
 * Minimal multilingual support and theme management for the simplified website
 */

class ThemeManager {
    constructor() {
        this.currentTheme = this.detectTheme();
        this.init();
    }

    /**
     * Detect preferred theme based on user preference or system settings
     * @returns {string} 'light' or 'dark'
     */
    detectTheme() {
        // 1. Check localStorage for saved preference
        const savedTheme = localStorage.getItem('focus-game-deck-theme');
        if (savedTheme && ['light', 'dark'].includes(savedTheme)) {
            return savedTheme;
        }

        // 2. Check browser/system preference
        if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
            return 'dark';
        }

        // 3. Default to light mode
        return 'light';
    }

    /**
     * Initialize theme management
     */
    init() {
        this.applyTheme(this.currentTheme);
        this.setupThemeToggle();
        this.watchSystemThemeChanges();
    }

    /**
     * Apply theme to the document
     * @param {string} theme - 'light' or 'dark'
     */
    applyTheme(theme) {
        document.documentElement.setAttribute('data-theme', theme);
        this.currentTheme = theme;
        localStorage.setItem('focus-game-deck-theme', theme);
    }

    /**
     * Toggle between light and dark themes
     */
    toggleTheme() {
        const newTheme = this.currentTheme === 'light' ? 'dark' : 'light';
        this.applyTheme(newTheme);
    }

    /**
     * Setup theme toggle button event listener
     */
    setupThemeToggle() {
        const themeToggle = document.getElementById('theme-toggle');
        if (themeToggle) {
            themeToggle.addEventListener('click', () => {
                this.toggleTheme();
            });
        }
    }

    /**
     * Watch for system theme changes and update accordingly
     */
    watchSystemThemeChanges() {
        if (window.matchMedia) {
            const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
            mediaQuery.addEventListener('change', (e) => {
                // Only auto-update if user hasn't manually set a preference
                const savedTheme = localStorage.getItem('focus-game-deck-theme');
                if (!savedTheme) {
                    const systemTheme = e.matches ? 'dark' : 'light';
                    this.applyTheme(systemTheme);
                }
            });
        }
    }
}

class I18n {
    constructor() {
        this.currentLanguage = this.detectLanguage();
        this.messages = {};
        this.init();
    }

    detectLanguage() {
        const stored = localStorage.getItem('focus-game-deck-language');
        if (stored && ['ja', 'zh-CN', 'en'].includes(stored)) {
            return stored;
        }

        const browserLang = navigator.language || navigator.userLanguage;
        if (browserLang.startsWith('ja')) return 'ja';
        if (browserLang.startsWith('zh')) return 'zh-CN';
        return 'en';
    }

    async init() {
        try {
            await this.loadMessages();
            this.updateLanguageSelector();
            this.translatePage();
            this.setupLanguageSelector();
        } catch (error) {
            console.error('Failed to initialize i18n:', error);
        }
    }

    async loadMessages() {
        try {
            const response = await fetch('./messages.json');
            if (!response.ok) throw new Error(`HTTP ${response.status}`);
            this.messages = await response.json();
        } catch (error) {
            console.error('Error loading translations:', error);
            this.messages = { ja: {}, 'zh-CN': {}, en: {} };
        }
    }

    updateLanguageSelector() {
        const selector = document.getElementById('language-select');
        if (selector) selector.value = this.currentLanguage;
    }

    setupLanguageSelector() {
        const selector = document.getElementById('language-select');
        if (selector) {
            selector.addEventListener('change', (event) => {
                this.changeLanguage(event.target.value);
            });
        }
    }

    changeLanguage(langCode) {
        if (['ja', 'zh-CN', 'en'].includes(langCode)) {
            this.currentLanguage = langCode;
            localStorage.setItem('focus-game-deck-language', langCode);
            this.translatePage();
        }
    }

    translatePage() {
        const currentMessages = this.messages[this.currentLanguage] || {};
        const elements = document.querySelectorAll('[data-i18n]');

        elements.forEach(element => {
            const key = element.getAttribute('data-i18n');
            const translation = currentMessages[key];

            if (translation) {
                if (element.tagName === 'INPUT' && (element.type === 'button' || element.type === 'submit')) {
                    element.value = translation;
                } else if (element.tagName === 'IMG') {
                    element.alt = translation;
                } else {
                    element.textContent = translation;
                }
            }
        });

        if (currentMessages['site_title']) {
            document.title = currentMessages['site_title'];
        }

        document.documentElement.lang = this.currentLanguage;
    }
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    // Initialize theme management
    window.themeManager = new ThemeManager();

    // Initialize internationalization
    window.i18n = new I18n();

    // Simple smooth scrolling
    const links = document.querySelectorAll('a[href^="#"]');
    links.forEach(link => {
        link.addEventListener('click', function (e) {
            e.preventDefault();
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                target.scrollIntoView({ behavior: 'smooth' });
            }
        });
    });
});
