<!DOCTYPE html>
<html lang="zh">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0">
    <title>阅读</title>
    <link rel="icon" type="image/png" href="{{ url_for('static', filename='生成阅读类图标.png') }}">
    <style>
        /* 基本样式重置 */
        body, html {
            margin: 0;
            padding: 0;
            font-family: "SimSun", "宋体", serif; /* 使用宋体 */
            background-color: #f9f4e8; /* 淡黄色背景 */
            color: #333;
            line-height: 1.8; /* 增加行高以便阅读 */
            -webkit-text-size-adjust: 100%; /* 防止iOS中横屏时自动调整字体大小 */
        }
        
        /* 页面主要内容区域 */
        .main-content {
            padding: 20px; /* 在内容周围添加一些边距 */
            max-width: 100%;
            margin: 0 auto;
        }

        /* 字体控制按钮样式 */
        .font-controls {
            position: fixed; /* 固定位置 */
            top: 10px;
            right: 0;
            background-color: rgba(255, 255, 255, 0.8); /* 半透明背景 */
            padding: 8px;
            border-radius: 5px 0 0 5px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.2);
            z-index: 1000; /* 确保在最上层 */
            transition: transform 0.3s ease, opacity 0.3s ease; /* 添加过渡效果 */
        }
        /* 隐藏状态 - 只显示左侧条 */
        .font-controls.collapsed {
            transform: translateX(calc(100% - 10px));
            opacity: 0.7;
        }
        /* 左侧条样式 */
        .font-controls:before {
            content: "";
            position: absolute;
            left: 0;
            top: 0;
            width: 10px;
            height: 100%;
            background-color: #777;
            border-radius: 5px 0 0 5px;
            cursor: pointer;
        }
        /* 按钮在隐藏状态时不可见 */
        .font-controls.collapsed button {
            opacity: 0;
            pointer-events: none; /* 禁止点击 */
        }
        .font-controls button {
            padding: 8px 12px; /* 增大按钮区域，便于在移动端点击 */
            margin-left: 5px;
            cursor: pointer;
            border: 1px solid #ccc;
            background-color: #fff;
            font-size: 16px;
            border-radius: 3px;
            touch-action: manipulation; /* 优化触摸操作 */
            transition: opacity 0.3s ease; /* 添加透明度过渡 */
        }
        .font-controls button:hover {
            background-color: #eee;
        }
        .font-controls button:active {
            background-color: #ddd; /* 按下效果 */
        }

        /* 经文文本块样式 */
        .scripture-block {
            margin-bottom: 40px; /* 在两篇经文之间添加间距 */
            font-size: 18px; /* 默认字体大小稍微增大，方便移动端阅读 */
            font-weight: normal; /* 默认不加粗 */
            white-space: pre-wrap; /* 保留换行和空格 */
            overflow-wrap: break-word; /* 确保长文本能够换行 */
            word-break: break-word; /* 长单词断行 */
        }
        
        /* 响应式设计 */
        @media screen and (min-width: 768px) {
            /* 桌面端样式 */
            .main-content {
                padding: 30px;
                width: 90%;
                max-width: 1200px;
            }
            .scripture-block {
                font-size: 20px; /* 大屏幕上使用较大的默认字体 */
            }
        }
        
        @media screen and (max-width: 767px) {
            /* 移动端样式 */
            .main-content {
                padding: 15px 10px;
            }
            body, html {
                line-height: 1.6; /* 移动端减小行高，节省空间 */
            }
            .font-controls {
                top: 5px;
            }
            .font-controls button {
                padding: 10px 15px; /* 更大的按钮区域，更容易点击 */
            }
            /* 添加暗黑模式支持 */
            @media (prefers-color-scheme: dark) {
                body, html {
                    background-color: #121212;
                    color: #e0e0e0;
                }
                .font-controls {
                    background-color: rgba(40, 40, 40, 0.8);
                }
                .font-controls:before {
                    background-color: #444;
                }
                .font-controls button {
                    background-color: #333;
                    color: #fff;
                    border-color: #555;
                }
                .font-controls button:hover {
                    background-color: #444;
                }
                .font-controls button:active {
                    background-color: #555;
                }
            }
        }
        
        /* 夜间模式按钮 */
        .dark-mode-toggle {
            margin-left: 10px;
            padding: 8px 12px;
            background-color: #fff;
            border: 1px solid #ccc;
            border-radius: 3px;
            cursor: pointer;
        }
        
        /* 暗模式类 */
        .dark-mode {
            background-color: #121212 !important;
            color: #e0e0e0 !important;
        }
        .dark-mode .font-controls {
            background-color: rgba(40, 40, 40, 0.8);
        }
        .dark-mode .font-controls:before {
            background-color: #555;
        }
        .dark-mode .font-controls button, 
        .dark-mode .dark-mode-toggle {
            background-color: #333;
            color: #fff;
            border-color: #555;
        }
        .dark-mode .font-controls button:hover, 
        .dark-mode .dark-mode-toggle:hover {
            background-color: #444;
        }
    </style>
</head>
<body>

    <!-- 字体大小控制按钮 -->
    <div class="font-controls collapsed" id="fontControls">
        <button onclick="changeFontSize('increase')" title="增大字体">A+</button>
        <button onclick="changeFontSize('decrease')" title="减小字体">A-</button>
        <button id="darkModeToggle" class="dark-mode-toggle" title="切换夜间模式">🌓</button>
    </div>

    <div class="main-content">
        <!-- 显示金刚经 -->
        <div class="scripture-block" id="jingang-content">
            {{ jingang_content | replace('\n', '<br>') | safe }}
        </div>

        <hr style="margin: 30px 0; border: none; border-top: 1px solid #ddd;"> <!-- 添加分隔线 -->

        <!-- 显示大悲咒 -->
        <div class="scripture-block" id="dabei-content">
            {{ dabei_content | replace('\n', '<br>') | safe }}
        </div>
    </div>

    <script>
        // 字体大小调整函数
        function changeFontSize(operation) {
            const scriptureBlocks = document.querySelectorAll('.scripture-block');
            scriptureBlocks.forEach(block => {
                // 尝试获取当前字体大小，如果未设置则使用默认值
                let currentSize = parseInt(window.getComputedStyle(block).fontSize) || 18; 
                
                if (operation === 'increase') {
                    currentSize += 2;
                } else if (operation === 'decrease' && currentSize > 12) { // 最小字体 12px
                    currentSize -= 2;
                }
                
                block.style.fontSize = currentSize + 'px';
                // 保存最后设置的大小，以便下次加载时应用
                localStorage.setItem('scripture_font_size', currentSize); 
            });
        }

        // 夜间模式切换函数
        function toggleDarkMode() {
            const body = document.body;
            body.classList.toggle('dark-mode');
            const isDarkMode = body.classList.contains('dark-mode');
            localStorage.setItem('dark_mode', isDarkMode ? 'enabled' : 'disabled');
            
            // 更新按钮图标
            document.getElementById('darkModeToggle').textContent = isDarkMode ? '☀️' : '🌓';
        }

        // 添加触摸滑动手势支持
        let touchStartX, touchEndX;
        const MIN_SWIPE_DISTANCE = 50;

        document.addEventListener('touchstart', function(e) {
            touchStartX = e.changedTouches[0].screenX;
        }, false);

        document.addEventListener('touchend', function(e) {
            touchEndX = e.changedTouches[0].screenX;
            handleSwipe();
        }, false);

        function handleSwipe() {
            if (touchEndX - touchStartX > MIN_SWIPE_DISTANCE) {
                // 右滑动，减小字体
                changeFontSize('decrease');
            } else if (touchStartX - touchEndX > MIN_SWIPE_DISTANCE) {
                // 左滑动，增大字体
                changeFontSize('increase');
            }
        }

        // 字体控制条的显示/隐藏逻辑
        const fontControls = document.getElementById('fontControls');
        let controlsTimer = null;
        
        // 切换控制条的状态
        function toggleControls() {
            fontControls.classList.toggle('collapsed');
        }
        
        // 显示控制条
        function showControls() {
            fontControls.classList.remove('collapsed');
            
            // 设置定时器，3秒后自动隐藏
            clearTimeout(controlsTimer);
            controlsTimer = setTimeout(() => {
                fontControls.classList.add('collapsed');
            }, 3000);
        }
        
        // 为控制条添加点击事件
        fontControls.addEventListener('click', function(e) {
            // 如果点击的是控制条本身（而不是按钮），切换显示/隐藏状态
            if (e.target === fontControls || e.target === fontControls.querySelector(':before')) {
                toggleControls();
                e.stopPropagation();
            }
        });
        
        // 滚动时显示控制条
        let lastScrollTop = 0;
        window.addEventListener('scroll', function() {
            const currentScrollTop = window.pageYOffset || document.documentElement.scrollTop;
            
            // 注释掉自动显示的部分，滚动时不再自动显示控制条
            // if (Math.abs(currentScrollTop - lastScrollTop) > 20) {
            //     showControls();
            //     lastScrollTop = currentScrollTop;
            // }
            
            // 仅更新滚动位置记录
            lastScrollTop = currentScrollTop;
        });
        
        // 点击页面其他地方时隐藏控制条
        document.addEventListener('click', function(e) {
            if (!fontControls.contains(e.target)) {
                fontControls.classList.add('collapsed');
            }
        });

        // 页面加载时执行
        window.onload = function() {
            // 应用保存的字体大小
            const savedFontSize = localStorage.getItem('scripture_font_size');
            if (savedFontSize) {
                const scriptureBlocks = document.querySelectorAll('.scripture-block');
                scriptureBlocks.forEach(block => {
                    block.style.fontSize = savedFontSize + 'px';
                });
            }
            
            // 应用保存的暗黑模式设置
            const savedDarkMode = localStorage.getItem('dark_mode');
            if (savedDarkMode === 'enabled') {
                document.body.classList.add('dark-mode');
                document.getElementById('darkModeToggle').textContent = '☀️';
            }
            
            // 添加夜间模式点击事件
            document.getElementById('darkModeToggle').addEventListener('click', toggleDarkMode);
            
            // 检测系统暗黑模式偏好
            if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches && !localStorage.getItem('dark_mode')) {
                document.body.classList.add('dark-mode');
                document.getElementById('darkModeToggle').textContent = '☀️';
            }
        };
    </script>

</body>
</html> 
