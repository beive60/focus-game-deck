/**
 * Focus Game Deck - Simple Internationalization Script
 * Minimal multilingual support for the simplified website
 */

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
