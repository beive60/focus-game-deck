// Focus Game Deck - Landing Page Interactive Script

document.addEventListener('DOMContentLoaded', function() {
    // 多言語対応の初期化
    initializeI18n();
    
    // ナビゲーションの初期化
    initializeNavigation();
    
    // スムーズスクロールの初期化
    initializeSmoothScroll();
    
    // FAQの初期化
    initializeFAQ();
    
    // スクロールアニメーションの初期化
    initializeScrollAnimations();
    
    // パーティクル効果の初期化（オプション）
    initializeParticleEffect();
});

// 多言語対応の翻訳データ
const translations = {
    ja: {
        // ナビゲーション
        nav_features: '機能',
        nav_benefits: 'メリット',
        nav_download: 'ダウンロード',
        nav_faq: 'FAQ',
        nav_language: '言語',
        
        // ヒーローセクション
        hero_title_focus: 'FOCUS',
        hero_title_game: 'GAME',
        hero_title_deck: 'DECK',
        hero_subtitle: 'ゲーミング集中力向上ツール',
        hero_description: 'プロゲーマーレベルの集中力を手に入れよう。Focus Game Deckは、ゲーミング中の集中力とパフォーマンスを最大化するために設計されたPowerShellベースの軽量ツールです。',
        hero_btn_download: 'ダウンロード',
        hero_btn_learn_more: '詳細を見る',
        scroll_text: 'スクロールして詳細を見る',
        
        // 機能セクション
        features_title: '強力な機能',
        features_subtitle: 'ゲーミングに特化した集中力向上機能',
        feature1_title: 'ディストラクション・ブロック',
        feature1_desc: 'ゲーミング中の不要な通知やアプリケーションを自動的にブロックし、100%ゲームに集中できる環境を作ります。',
        feature2_title: 'パフォーマンス最適化',
        feature2_desc: 'システムリソースを最適化し、FPSの安定化とレイテンシの最小化でゲーミングパフォーマンスを向上させます。',
        feature3_title: 'OBS連携',
        feature3_desc: 'OBSとシームレスに連携し、配信者向けの自動シーン切り替えやアラート機能で配信をレベルアップ。',
        feature4_title: 'カスタムプロファイル',
        feature4_desc: 'ゲームごとに異なる設定プロファイルを作成し、タイトルに最適化された環境を瞬時に構築できます。',
        feature5_title: 'リアルタイム監視',
        feature5_desc: 'CPU、GPU、メモリ使用率をリアルタイムで監視し、パフォーマンスの低下を事前に防ぎます。',
        feature6_title: 'ホットキー制御',
        feature6_desc: 'カスタマイズ可能なホットキーで、ゲーム中でも素早く設定を調整できます。',
        
        // メリットセクション
        benefits_title: 'Focus Game Deckを選ぶ理由',
        benefits_subtitle: 'プロレベルのゲーミング環境を誰でも簡単に',
        benefit1_title: '集中力向上',
        benefit1_desc: '不要な通知とバックグラウンドプロセスを完全に排除し、ゲームだけに集中できる環境を構築します。',
        benefit2_title: 'パフォーマンス向上',
        benefit2_desc: 'システムリソースの最適化により、平均15-25%のFPS向上とレイテンシ削減を実現します。',
        benefit3_title: '簡単セットアップ',
        benefit3_desc: 'PowerShellベースの軽量ツールで、複雑な設定は不要。ワンクリックで最適な環境を構築できます。',
        stat1_number: '25%',
        stat1_label: 'FPS向上',
        stat2_number: '50%',
        stat2_label: '集中力UP',
        stat3_number: '30%',
        stat3_label: '反応速度向上',
        
        // ダウンロードセクション
        download_title: 'Focus Game Deckをダウンロード',
        download_subtitle: '今すぐゲーミングパフォーマンスを向上させよう',
        download_free_title: '無料版',
        download_pro_title: 'Pro版',
        download_version: 'v1.2.0',
        download_free_feature1: '基本的なディストラクション・ブロック',
        download_free_feature2: 'パフォーマンス監視',
        download_free_feature3: '3つのプリセットプロファイル',
        download_free_feature4: 'コミュニティサポート',
        download_pro_feature1: 'すべての無料版機能',
        download_pro_feature2: 'OBS完全連携',
        download_pro_feature3: '無制限カスタムプロファイル',
        download_pro_feature4: 'AIベース最適化',
        download_pro_feature5: '優先サポート',
        download_pro_feature6: '自動アップデート',
        download_free_btn: '無料でダウンロード',
        download_pro_btn: 'Pro版を購入 ¥2,980',
        download_size: 'サイズ',
        download_platform: 'Windows 10/11',
        
        // システム要件
        system_requirements: 'システム要件',
        req_os: 'OS: Windows 10 (1903以降) または Windows 11',
        req_powershell: 'PowerShell: 5.1以降 (Windows PowerShell) または 7.0以降 (PowerShell Core)',
        req_memory: 'メモリ: 4GB RAM以上',
        req_storage: 'ストレージ: 50MB の空き容量',
        req_network: 'ネットワーク: アップデート用インターネット接続',
        req_optional: 'オプション: OBS Studio (OBS連携機能使用時)',
        
        // FAQ
        faq_title: 'よくある質問',
        faq_subtitle: 'Focus Game Deckについての疑問にお答えします',
        faq1_q: 'Focus Game Deckは無料で使えますか？',
        faq1_a: 'はい、基本機能は無料でご利用いただけます。より高度な機能をお求めの場合は、Pro版をご検討ください。',
        faq2_q: '対応しているゲームはありますか？',
        faq2_a: 'Focus Game Deckはゲームに依存しないシステムレベルの最適化を行うため、すべてのPCゲームで効果を発揮します。',
        faq3_q: 'OBS連携機能はどのように動作しますか？',
        faq3_a: 'OBSのWebSocketプラグインを通じて、ゲームの開始/終了に合わせて自動的にシーンを切り替えたり、アラートを表示したりできます。',
        faq4_q: 'アンインストールは簡単にできますか？',
        faq4_a: 'はい、PowerShellスクリプトベースのため、システムに深く統合されることなく、簡単にアンインストールできます。',
        
        // フッター
        footer_title: 'Focus Game Deck',
        footer_desc: 'プロゲーマーレベルの集中力を手に入れるためのゲーミング特化ツール',
        footer_quick_links: 'クイックリンク',
        footer_features: '機能',
        footer_download: 'ダウンロード',
        footer_support: 'サポート',
        footer_documentation: 'ドキュメント',
        footer_community: 'コミュニティ',
        footer_github: 'GitHub',
        footer_discord: 'Discord',
        footer_social: 'ソーシャル',
        footer_copyright: '© 2025 Focus Game Deck. All rights reserved.',
        footer_privacy: 'プライバシーポリシー',
        footer_terms: '利用規約'
    },
    en: {
        // Navigation
        nav_features: 'Features',
        nav_benefits: 'Benefits',
        nav_download: 'Download',
        nav_faq: 'FAQ',
        nav_language: 'Language',
        
        // Hero Section
        hero_title_focus: 'FOCUS',
        hero_title_game: 'GAME',
        hero_title_deck: 'DECK',
        hero_subtitle: 'Gaming Focus Enhancement Tool',
        hero_description: 'Achieve pro-gamer level focus. Focus Game Deck is a lightweight PowerShell-based tool designed to maximize focus and performance during gaming sessions.',
        hero_btn_download: 'Download',
        hero_btn_learn_more: 'Learn More',
        scroll_text: 'Scroll to learn more',
        
        // Features Section
        features_title: 'Powerful Features',
        features_subtitle: 'Gaming-focused concentration enhancement features',
        feature1_title: 'Distraction Block',
        feature1_desc: 'Automatically blocks unnecessary notifications and applications during gaming, creating a 100% game-focused environment.',
        feature2_title: 'Performance Optimization',
        feature2_desc: 'Optimizes system resources to stabilize FPS and minimize latency, enhancing gaming performance.',
        feature3_title: 'OBS Integration',
        feature3_desc: 'Seamlessly integrates with OBS for streamers with automatic scene switching and alert features to level up your streaming.',
        feature4_title: 'Custom Profiles',
        feature4_desc: 'Create different configuration profiles for each game and instantly build environments optimized for specific titles.',
        feature5_title: 'Real-time Monitoring',
        feature5_desc: 'Monitor CPU, GPU, and memory usage in real-time to prevent performance degradation in advance.',
        feature6_title: 'Hotkey Control',
        feature6_desc: 'Quickly adjust settings during gameplay with customizable hotkeys.',
        
        // Benefits Section
        benefits_title: 'Why Choose Focus Game Deck',
        benefits_subtitle: 'Pro-level gaming environment made simple for everyone',
        benefit1_title: 'Enhanced Focus',
        benefit1_desc: 'Completely eliminates unnecessary notifications and background processes, creating an environment where you can focus solely on gaming.',
        benefit2_title: 'Performance Boost',
        benefit2_desc: 'System resource optimization achieves an average 15-25% FPS improvement and latency reduction.',
        benefit3_title: 'Easy Setup',
        benefit3_desc: 'Lightweight PowerShell-based tool with no complex configuration required. Build the optimal environment with one click.',
        stat1_number: '25%',
        stat1_label: 'FPS Boost',
        stat2_number: '50%',
        stat2_label: 'Focus UP',
        stat3_number: '30%',
        stat3_label: 'Reaction Speed',
        
        // Download Section
        download_title: 'Download Focus Game Deck',
        download_subtitle: 'Enhance your gaming performance right now',
        download_free_title: 'Free Version',
        download_pro_title: 'Pro Version',
        download_version: 'v1.2.0',
        download_free_feature1: 'Basic distraction blocking',
        download_free_feature2: 'Performance monitoring',
        download_free_feature3: '3 preset profiles',
        download_free_feature4: 'Community support',
        download_pro_feature1: 'All free version features',
        download_pro_feature2: 'Full OBS integration',
        download_pro_feature3: 'Unlimited custom profiles',
        download_pro_feature4: 'AI-based optimization',
        download_pro_feature5: 'Priority support',
        download_pro_feature6: 'Automatic updates',
        download_free_btn: 'Download Free',
        download_pro_btn: 'Buy Pro $29.99',
        download_size: 'Size',
        download_platform: 'Windows 10/11',
        
        // System Requirements
        system_requirements: 'System Requirements',
        req_os: 'OS: Windows 10 (1903 or later) or Windows 11',
        req_powershell: 'PowerShell: 5.1 or later (Windows PowerShell) or 7.0 or later (PowerShell Core)',
        req_memory: 'Memory: 4GB RAM or higher',
        req_storage: 'Storage: 50MB free space',
        req_network: 'Network: Internet connection for updates',
        req_optional: 'Optional: OBS Studio (for OBS integration features)',
        
        // FAQ
        faq_title: 'Frequently Asked Questions',
        faq_subtitle: 'Answers to your questions about Focus Game Deck',
        faq1_q: 'Is Focus Game Deck free to use?',
        faq1_a: 'Yes, basic features are available for free. For more advanced features, please consider the Pro version.',
        faq2_q: 'Are there supported games?',
        faq2_a: 'Focus Game Deck performs game-independent system-level optimization, so it works effectively with all PC games.',
        faq3_q: 'How does the OBS integration feature work?',
        faq3_a: 'Through OBS WebSocket plugin, it can automatically switch scenes and display alerts based on game start/end events.',
        faq4_q: 'Is uninstallation easy?',
        faq4_a: 'Yes, being PowerShell script-based, it can be easily uninstalled without deep system integration.',
        
        // Footer
        footer_title: 'Focus Game Deck',
        footer_desc: 'Gaming-focused tool for achieving pro-gamer level concentration',
        footer_quick_links: 'Quick Links',
        footer_features: 'Features',
        footer_download: 'Download',
        footer_support: 'Support',
        footer_documentation: 'Documentation',
        footer_community: 'Community',
        footer_github: 'GitHub',
        footer_discord: 'Discord',
        footer_social: 'Social',
        footer_copyright: '© 2025 Focus Game Deck. All rights reserved.',
        footer_privacy: 'Privacy Policy',
        footer_terms: 'Terms of Service'
    }
};

// 多言語対応の初期化
function initializeI18n() {
    // ブラウザの言語設定を取得
    const browserLang = navigator.language || navigator.userLanguage;
    
    // ローカルストレージから保存された言語設定を取得
    const savedLang = localStorage.getItem('focusGameDeckLang');
    
    // 言語を決定（優先順位: 保存された設定 > ブラウザ設定 > デフォルト英語）
    let currentLang = 'en'; // デフォルトは英語
    
    if (savedLang && translations[savedLang]) {
        currentLang = savedLang;
    } else if (browserLang.startsWith('ja')) {
        currentLang = 'ja';
    }
    
    // 言語を設定
    setLanguage(currentLang);
    
    // 言語切り替えイベントリスナーを設定
    setupLanguageSwitcher();
}

// 言語切り替え機能のセットアップ
function setupLanguageSwitcher() {
    const languageToggle = document.getElementById('language-toggle');
    const languageMenu = document.getElementById('language-menu');
    const languageOptions = document.querySelectorAll('.language-option');
    
    if (languageToggle && languageMenu) {
        // 言語メニューのトグル
        languageToggle.addEventListener('click', function(e) {
            e.preventDefault();
            e.stopPropagation();
            languageMenu.classList.toggle('active');
        });
        
        // 言語オプションのクリック処理
        languageOptions.forEach(option => {
            option.addEventListener('click', function(e) {
                e.preventDefault();
                const selectedLang = this.getAttribute('data-lang');
                setLanguage(selectedLang);
                languageMenu.classList.remove('active');
            });
        });
        
        // メニュー外クリックで閉じる
        document.addEventListener('click', function(e) {
            if (!languageToggle.contains(e.target) && !languageMenu.contains(e.target)) {
                languageMenu.classList.remove('active');
            }
        });
    }
}

// 言語設定
function setLanguage(lang) {
    if (!translations[lang]) {
        console.warn(`Language ${lang} not found, falling back to English`);
        lang = 'en';
    }
    
    const t = translations[lang];
    
    // HTML言語属性を設定
    document.documentElement.lang = lang;
    
    // 各要素のテキストを更新
    updateElementText('nav-features', t.nav_features);
    updateElementText('nav-benefits', t.nav_benefits);
    updateElementText('nav-download', t.nav_download);
    updateElementText('nav-faq', t.nav_faq);
    updateElementText('nav-language', t.nav_language);
    
    // ヒーローセクション
    updateElementText('hero-title-focus', t.hero_title_focus);
    updateElementText('hero-title-game', t.hero_title_game);
    updateElementText('hero-title-deck', t.hero_title_deck);
    updateElementText('hero-subtitle', t.hero_subtitle);
    updateElementText('hero-description', t.hero_description);
    updateElementText('hero-btn-download', t.hero_btn_download);
    updateElementText('hero-btn-learn-more', t.hero_btn_learn_more);
    updateElementText('scroll-text', t.scroll_text);
    
    // 機能セクション
    updateElementText('features-title', t.features_title);
    updateElementText('features-subtitle', t.features_subtitle);
    updateElementText('feature1-title', t.feature1_title);
    updateElementText('feature1-desc', t.feature1_desc);
    updateElementText('feature2-title', t.feature2_title);
    updateElementText('feature2-desc', t.feature2_desc);
    updateElementText('feature3-title', t.feature3_title);
    updateElementText('feature3-desc', t.feature3_desc);
    updateElementText('feature4-title', t.feature4_title);
    updateElementText('feature4-desc', t.feature4_desc);
    updateElementText('feature5-title', t.feature5_title);
    updateElementText('feature5-desc', t.feature5_desc);
    updateElementText('feature6-title', t.feature6_title);
    updateElementText('feature6-desc', t.feature6_desc);
    
    // メリットセクション
    updateElementText('benefits-title', t.benefits_title);
    updateElementText('benefits-subtitle', t.benefits_subtitle);
    updateElementText('benefit1-title', t.benefit1_title);
    updateElementText('benefit1-desc', t.benefit1_desc);
    updateElementText('benefit2-title', t.benefit2_title);
    updateElementText('benefit2-desc', t.benefit2_desc);
    updateElementText('benefit3-title', t.benefit3_title);
    updateElementText('benefit3-desc', t.benefit3_desc);
    updateElementText('stat1-number', t.stat1_number);
    updateElementText('stat1-label', t.stat1_label);
    updateElementText('stat2-number', t.stat2_number);
    updateElementText('stat2-label', t.stat2_label);
    updateElementText('stat3-number', t.stat3_number);
    updateElementText('stat3-label', t.stat3_label);
    
    // ダウンロードセクション
    updateElementText('download-title', t.download_title);
    updateElementText('download-subtitle', t.download_subtitle);
    updateElementText('download-free-title', t.download_free_title);
    updateElementText('download-pro-title', t.download_pro_title);
    updateElementText('download-version', t.download_version);
    updateElementText('download-free-feature1', t.download_free_feature1);
    updateElementText('download-free-feature2', t.download_free_feature2);
    updateElementText('download-free-feature3', t.download_free_feature3);
    updateElementText('download-free-feature4', t.download_free_feature4);
    updateElementText('download-pro-feature1', t.download_pro_feature1);
    updateElementText('download-pro-feature2', t.download_pro_feature2);
    updateElementText('download-pro-feature3', t.download_pro_feature3);
    updateElementText('download-pro-feature4', t.download_pro_feature4);
    updateElementText('download-pro-feature5', t.download_pro_feature5);
    updateElementText('download-pro-feature6', t.download_pro_feature6);
    updateElementText('download-free-btn', t.download_free_btn);
    updateElementText('download-pro-btn', t.download_pro_btn);
    updateElementText('download-size', t.download_size);
    updateElementText('download-platform', t.download_platform);
    
    // システム要件
    updateElementText('system-requirements', t.system_requirements);
    updateElementText('req-os', t.req_os);
    updateElementText('req-powershell', t.req_powershell);
    updateElementText('req-memory', t.req_memory);
    updateElementText('req-storage', t.req_storage);
    updateElementText('req-network', t.req_network);
    updateElementText('req-optional', t.req_optional);
    
    // FAQ
    updateElementText('faq-title', t.faq_title);
    updateElementText('faq-subtitle', t.faq_subtitle);
    updateElementText('faq1-q', t.faq1_q);
    updateElementText('faq1-a', t.faq1_a);
    updateElementText('faq2-q', t.faq2_q);
    updateElementText('faq2-a', t.faq2_a);
    updateElementText('faq3-q', t.faq3_q);
    updateElementText('faq3-a', t.faq3_a);
    updateElementText('faq4-q', t.faq4_q);
    updateElementText('faq4-a', t.faq4_a);
    
    // フッター
    updateElementText('footer-title', t.footer_title);
    updateElementText('footer-desc', t.footer_desc);
    updateElementText('footer-quick-links', t.footer_quick_links);
    updateElementText('footer-features', t.footer_features);
    updateElementText('footer-download', t.footer_download);
    updateElementText('footer-support', t.footer_support);
    updateElementText('footer-documentation', t.footer_documentation);
    updateElementText('footer-community', t.footer_community);
    updateElementText('footer-github', t.footer_github);
    updateElementText('footer-discord', t.footer_discord);
    updateElementText('footer-social', t.footer_social);
    updateElementText('footer-copyright', t.footer_copyright);
    updateElementText('footer-privacy', t.footer_privacy);
    updateElementText('footer-terms', t.footer_terms);
    
    // 現在の言語をローカルストレージに保存
    localStorage.setItem('focusGameDeckLang', lang);
    
    // 言語切り替えボタンの表示を更新
    updateLanguageToggle(lang);
}

// 要素のテキストを更新する関数
function updateElementText(id, text) {
    const element = document.getElementById(id);
    if (element) {
        element.textContent = text;
    }
}

// 言語切り替えボタンの表示を更新
function updateLanguageToggle(currentLang) {
    const languageToggle = document.getElementById('language-toggle');
    const languageOptions = document.querySelectorAll('.language-option');
    
    if (languageToggle) {
        const langDisplay = currentLang === 'ja' ? '日本語' : 'English';
        const langFlag = currentLang === 'ja' ? '🇯🇵' : '🇺🇸';
        languageToggle.innerHTML = `${langFlag} ${langDisplay} <svg class="language-arrow" width="12" height="12" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="m19 9-7 7-7-7"></path></svg>`;
    }
    
    // 言語オプションの選択状態を更新
    languageOptions.forEach(option => {
        const optionLang = option.getAttribute('data-lang');
        if (optionLang === currentLang) {
            option.classList.add('active');
        } else {
            option.classList.remove('active');
        }
    });
}

// ナビゲーション関連
function initializeNavigation() {
    const hamburger = document.querySelector('.hamburger');
    const navMenu = document.querySelector('.nav-menu');
    const navLinks = document.querySelectorAll('.nav-link');

    // ハンバーガーメニューのトグル
    hamburger.addEventListener('click', function() {
        hamburger.classList.toggle('active');
        navMenu.classList.toggle('active');
        document.body.style.overflow = navMenu.classList.contains('active') ? 'hidden' : '';
    });

    // ナビゲーションリンククリック時の処理
    navLinks.forEach(link => {
        link.addEventListener('click', function() {
            hamburger.classList.remove('active');
            navMenu.classList.remove('active');
            document.body.style.overflow = '';
        });
    });

    // スクロール時のナビゲーションバー表示制御
    let lastScrollTop = 0;
    const navbar = document.querySelector('.navbar');
    
    window.addEventListener('scroll', function() {
        const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
        
        if (scrollTop > lastScrollTop && scrollTop > 100) {
            // 下にスクロール時は隠す
            navbar.style.transform = 'translateY(-100%)';
        } else {
            // 上にスクロール時は表示
            navbar.style.transform = 'translateY(0)';
        }
        
        // 背景の透明度調整
        if (scrollTop > 50) {
            navbar.style.background = 'rgba(10, 10, 10, 0.98)';
        } else {
            navbar.style.background = 'rgba(10, 10, 10, 0.95)';
        }
        
        lastScrollTop = scrollTop;
    });
}

// スムーズスクロール
function initializeSmoothScroll() {
    const links = document.querySelectorAll('a[href^="#"]');
    
    links.forEach(link => {
        link.addEventListener('click', function(e) {
            e.preventDefault();
            
            const targetId = this.getAttribute('href');
            const targetElement = document.querySelector(targetId);
            
            if (targetElement) {
                const headerOffset = 80;
                const elementPosition = targetElement.getBoundingClientRect().top;
                const offsetPosition = elementPosition + window.pageYOffset - headerOffset;

                window.scrollTo({
                    top: offsetPosition,
                    behavior: 'smooth'
                });
            }
        });
    });
}

// FAQ の展開/収束機能
function initializeFAQ() {
    const faqItems = document.querySelectorAll('.faq-item');
    
    faqItems.forEach(item => {
        const question = item.querySelector('.faq-question');
        
        question.addEventListener('click', function() {
            const isActive = item.classList.contains('active');
            
            // 他のすべてのFAQアイテムを閉じる
            faqItems.forEach(otherItem => {
                if (otherItem !== item) {
                    otherItem.classList.remove('active');
                }
            });
            
            // クリックされたアイテムをトグル
            item.classList.toggle('active', !isActive);
        });
    });
}

// スクロールアニメーション
function initializeScrollAnimations() {
    const observerOptions = {
        threshold: 0.1,
        rootMargin: '0px 0px -50px 0px'
    };

    const observer = new IntersectionObserver(function(entries) {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('animate-in');
                
                // カウンターアニメーション
                if (entry.target.classList.contains('stat-number')) {
                    animateCounter(entry.target);
                }
            }
        });
    }, observerOptions);

    // アニメーション対象要素を監視
    const animateElements = document.querySelectorAll(
        '.feature-card, .benefit-item, .stat-card, .download-card, .faq-item'
    );
    
    animateElements.forEach(el => {
        observer.observe(el);
    });

    // カウンターアニメーション用CSS追加
    addAnimationStyles();
}

// カウンターアニメーション
function animateCounter(element) {
    const text = element.textContent;
    const number = parseInt(text.match(/\d+/)[0]);
    const suffix = text.replace(/\d+/, '');
    const duration = 2000;
    const startTime = performance.now();

    function updateCounter(currentTime) {
        const elapsed = currentTime - startTime;
        const progress = Math.min(elapsed / duration, 1);
        
        // イージング関数
        const easeOutCubic = 1 - Math.pow(1 - progress, 3);
        const currentNumber = Math.floor(number * easeOutCubic);
        
        element.textContent = currentNumber + suffix;
        
        if (progress < 1) {
            requestAnimationFrame(updateCounter);
        } else {
            element.textContent = text; // 最終値を設定
        }
    }
    
    requestAnimationFrame(updateCounter);
}

// アニメーション用CSS動的追加
function addAnimationStyles() {
    const style = document.createElement('style');
    style.textContent = `
        .feature-card,
        .benefit-item,
        .stat-card,
        .download-card,
        .faq-item {
            opacity: 0;
            transform: translateY(30px);
            transition: all 0.6s cubic-bezier(0.4, 0, 0.2, 1);
        }
        
        .feature-card.animate-in,
        .benefit-item.animate-in,
        .stat-card.animate-in,
        .download-card.animate-in,
        .faq-item.animate-in {
            opacity: 1;
            transform: translateY(0);
        }
        
        .feature-card {
            transition-delay: 0.1s;
        }
        
        .feature-card:nth-child(2) {
            transition-delay: 0.2s;
        }
        
        .feature-card:nth-child(3) {
            transition-delay: 0.3s;
        }
        
        .feature-card:nth-child(4) {
            transition-delay: 0.4s;
        }
        
        .feature-card:nth-child(5) {
            transition-delay: 0.5s;
        }
        
        .feature-card:nth-child(6) {
            transition-delay: 0.6s;
        }
    `;
    document.head.appendChild(style);
}

// パーティクル効果（軽量版）
function initializeParticleEffect() {
    const hero = document.querySelector('.hero');
    const particleCount = 50;
    
    // パーティクルコンテナ作成
    const particleContainer = document.createElement('div');
    particleContainer.style.cssText = `
        position: absolute;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        pointer-events: none;
        overflow: hidden;
        z-index: 1;
    `;
    
    hero.appendChild(particleContainer);
    
    // パーティクル生成
    for (let i = 0; i < particleCount; i++) {
        createParticle(particleContainer);
    }
}

function createParticle(container) {
    const particle = document.createElement('div');
    const size = Math.random() * 3 + 1;
    const x = Math.random() * 100;
    const animationDuration = Math.random() * 20 + 10;
    const delay = Math.random() * 20;
    
    particle.style.cssText = `
        position: absolute;
        width: ${size}px;
        height: ${size}px;
        background: radial-gradient(circle, rgba(0, 255, 136, 0.8) 0%, rgba(0, 255, 136, 0) 70%);
        border-radius: 50%;
        left: ${x}%;
        top: 100%;
        animation: float-up ${animationDuration}s linear ${delay}s infinite;
        pointer-events: none;
    `;
    
    container.appendChild(particle);
    
    // パーティクル用キーフレームを追加
    if (!document.querySelector('#particle-keyframes')) {
        const style = document.createElement('style');
        style.id = 'particle-keyframes';
        style.textContent = `
            @keyframes float-up {
                0% {
                    transform: translateY(0) translateX(0);
                    opacity: 0;
                }
                10% {
                    opacity: 1;
                }
                90% {
                    opacity: 1;
                }
                100% {
                    transform: translateY(-100vh) translateX(${Math.random() * 100 - 50}px);
                    opacity: 0;
                }
            }
        `;
        document.head.appendChild(style);
    }
}

// ボタンクリック時のリップル効果
function addRippleEffect() {
    const buttons = document.querySelectorAll('.btn');
    
    buttons.forEach(button => {
        button.addEventListener('click', function(e) {
            const ripple = document.createElement('span');
            const rect = this.getBoundingClientRect();
            const size = Math.max(rect.width, rect.height);
            const x = e.clientX - rect.left - size / 2;
            const y = e.clientY - rect.top - size / 2;
            
            ripple.style.cssText = `
                position: absolute;
                width: ${size}px;
                height: ${size}px;
                left: ${x}px;
                top: ${y}px;
                background: rgba(255, 255, 255, 0.3);
                border-radius: 50%;
                transform: scale(0);
                animation: ripple 0.6s ease-out;
                pointer-events: none;
            `;
            
            this.style.position = 'relative';
            this.style.overflow = 'hidden';
            this.appendChild(ripple);
            
            setTimeout(() => {
                ripple.remove();
            }, 600);
        });
    });
    
    // リップルアニメーション用キーフレームを追加
    if (!document.querySelector('#ripple-keyframes')) {
        const style = document.createElement('style');
        style.id = 'ripple-keyframes';
        style.textContent = `
            @keyframes ripple {
                to {
                    transform: scale(2);
                    opacity: 0;
                }
            }
        `;
        document.head.appendChild(style);
    }
}

// マウス追従グラデーション効果
function initializeMouseGradient() {
    const hero = document.querySelector('.hero');
    let mouseX = 0;
    let mouseY = 0;
    
    hero.addEventListener('mousemove', function(e) {
        const rect = hero.getBoundingClientRect();
        mouseX = ((e.clientX - rect.left) / rect.width) * 100;
        mouseY = ((e.clientY - rect.top) / rect.height) * 100;
        
        hero.style.background = `
            radial-gradient(circle at ${mouseX}% ${mouseY}%, rgba(0, 255, 136, 0.1) 0%, transparent 50%),
            linear-gradient(135deg, var(--bg-darker), var(--bg-dark))
        `;
    });
    
    hero.addEventListener('mouseleave', function() {
        hero.style.background = 'linear-gradient(135deg, var(--bg-darker), var(--bg-dark))';
    });
}

// パフォーマンス監視
function initializePerformanceMonitoring() {
    if ('performance' in window) {
        window.addEventListener('load', function() {
            setTimeout(function() {
                const perfData = performance.getEntriesByType('navigation')[0];
                const loadTime = perfData.loadEventEnd - perfData.loadEventStart;
                
                if (loadTime > 3000) {
                    console.warn('ページの読み込み時間が3秒を超えています:', loadTime + 'ms');
                }
            }, 100);
        });
    }
}

// ダークモード対応（将来の機能拡張用）
function initializeDarkModeToggle() {
    // 現在はダークモードのみだが、将来的にライトモードも実装可能
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)');
    
    prefersDark.addEventListener('change', function(e) {
        if (e.matches) {
            document.body.classList.add('dark-mode');
        } else {
            document.body.classList.remove('dark-mode');
        }
    });
}

// エラーハンドリング
window.addEventListener('error', function(e) {
    console.error('JavaScript Error:', e.error);
    // 本番環境ではエラーレポートサービスに送信することを検討
});

// 初期化完了時の処理
window.addEventListener('load', function() {
    // リップル効果の追加
    addRippleEffect();
    
    // マウス追従効果の初期化
    initializeMouseGradient();
    
    // パフォーマンス監視の初期化
    initializePerformanceMonitoring();
    
    // ダークモード対応の初期化
    initializeDarkModeToggle();
    
    console.log('Focus Game Deck - Landing Page loaded successfully!');
});