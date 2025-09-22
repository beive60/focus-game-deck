// Focus Game Deck - Landing Page Interactive Script

document.addEventListener('DOMContentLoaded', function() {
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