
/**
 * SOUL RHYTHM 4.0 - ULTRA PREMIUM EDITION
 * Features: Melodic Audio Engine, Advanced VFX, Free-Click, Mobile Optimized
 */

const CONFIG = {
    laneCount: 4,
    baseSpeed: 10,
    laneInsetRatio: 0.15,
    laneNoteWidthRatio: 0.72,
    hitLineRatio: 0.84,
    colors: ['#ff0055', '#00e5ff', '#ffeb3b', '#76ff03'],
    laneGradients: [
        ['#ff0055', '#ff6b9d'],
        ['#00e5ff', '#0066ff'],
        ['#ffeb3b', '#ff9800'],
        ['#76ff03', '#00c853']
    ],
    particlesEnabled: true,
    soundEnabled: true,
    musicEnabled: true,
    vibrationEnabled: true
};

const DIFFICULTY = {
    easy: {
        spawnIntervalMs: 980,
        spawnFloorMs: 760,
        speedMul: 0.84,
        missGrace: 5,
        durationMs: 70000,
        longNoteChance: 0.04,
        maxVisibleTiles: 4
    },
    normal: {
        spawnIntervalMs: 820,
        spawnFloorMs: 620,
        speedMul: 1.0,
        missGrace: 3,
        durationMs: 65000,
        longNoteChance: 0.07,
        maxVisibleTiles: 5
    },
    hard: {
        spawnIntervalMs: 680,
        spawnFloorMs: 500,
        speedMul: 1.12,
        missGrace: 2,
        durationMs: 60000,
        longNoteChance: 0.10,
        maxVisibleTiles: 6
    }
};

const SPAWN_PATTERNS = [
    [1, 2, 1, 3, 2, 0, 1, 2],
    [0, 1, 2, 1, 3, 2, 1, 0],
    [3, 2, 1, 2, 0, 1, 2, 3],
    [0, 2, 1, 3, 2, 1, 0, 1],
    [2, 1, 3, 2, 0, 2, 1, 3],
];

// ============================================================
// MELODIC AUDIO ENGINE
// ============================================================
const AudioEngine = {
    ctx: null,
    masterGain: null,
    musicGain: null,
    sfxGain: null,
    reverbNode: null,
    compressor: null,

    // Pentatonic scale in multiple octaves for rich melody
    MELODY_SCALE: [261.63, 293.66, 329.63, 392.00, 440.00, 523.25, 587.33, 659.25, 783.99, 880.00],
    BASS_SCALE:   [65.41,  73.42,  82.41,  98.00,  110.00, 130.81],

    melodyPattern: [0, 2, 4, 7, 9, 7, 4, 2, 0, 4, 7, 9],
    melodyStep: 0,
    bassPattern: [0, 0, 3, 3, 5, 5, 2, 2],
    bassStep: 0,

    beatCount: 0,

    init() {
        if (this.ctx) { if (this.ctx.state === 'suspended') this.ctx.resume(); return; }
        this.ctx = new (window.AudioContext || window.webkitAudioContext)();

        // Compressor for loudness
        this.compressor = this.ctx.createDynamicsCompressor();
        this.compressor.threshold.value = -20;
        this.compressor.knee.value = 10;
        this.compressor.ratio.value = 4;
        this.compressor.attack.value = 0.003;
        this.compressor.release.value = 0.25;
        this.compressor.connect(this.ctx.destination);

        this.masterGain = this.ctx.createGain();
        this.masterGain.gain.value = 0.9;
        this.masterGain.connect(this.compressor);

        // Reverb
        this.reverbNode = this.createReverb();

        this.musicGain = this.ctx.createGain();
        this.musicGain.gain.value = 0.35;
        this.musicGain.connect(this.masterGain);

        this.sfxGain = this.ctx.createGain();
        this.sfxGain.gain.value = 0.7;
        this.sfxGain.connect(this.masterGain);

        this.startMusicLoop();
    },

    createReverb() {
        const convolver = this.ctx.createConvolver();
        const sr = this.ctx.sampleRate;
        const len = sr * 2;
        const buf = this.ctx.createBuffer(2, len, sr);
        for (let ch = 0; ch < 2; ch++) {
            const d = buf.getChannelData(ch);
            for (let i = 0; i < len; i++) {
                d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, 3);
            }
        }
        convolver.buffer = buf;
        const g = this.ctx.createGain();
        g.gain.value = 0.18;
        convolver.connect(g);
        g.connect(this.masterGain);
        return convolver;
    },

    playNote(freq, type, duration, gainVal, target) {
        if (!this.ctx) return;
        const osc = this.ctx.createOscillator();
        const g = this.ctx.createGain();
        osc.type = type;
        osc.frequency.setValueAtTime(freq, this.ctx.currentTime);
        // Vibrato
        const lfo = this.ctx.createOscillator();
        const lfoGain = this.ctx.createGain();
        lfo.frequency.value = 5;
        lfoGain.gain.value = freq * 0.01;
        lfo.connect(lfoGain);
        lfoGain.connect(osc.frequency);
        lfo.start();
        lfo.stop(this.ctx.currentTime + duration);

        g.gain.setValueAtTime(0, this.ctx.currentTime);
        g.gain.linearRampToValueAtTime(gainVal, this.ctx.currentTime + 0.01);
        g.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + duration);
        osc.connect(g);
        g.connect(target || this.musicGain);
        if (this.reverbNode) g.connect(this.reverbNode);
        osc.start();
        osc.stop(this.ctx.currentTime + duration);
    },

    playChord(root, type, duration) {
        // Major chord: root, major third (+4 semitones), fifth (+7 semitones)
        const semitone = Math.pow(2, 1/12);
        this.playNote(root, type, duration, 0.08, this.musicGain);
        this.playNote(root * Math.pow(semitone, 4), type, duration, 0.06, this.musicGain);
        this.playNote(root * Math.pow(semitone, 7), type, duration, 0.05, this.musicGain);
    },

    // Melodic music loop using setInterval
    musicIntervalId: null,
    startMusicLoop() {
        if (this.musicIntervalId) clearInterval(this.musicIntervalId);
        const BPM = 128;
        const beatMs = (60 / BPM) * 1000;
        const eighthMs = beatMs / 2;

        this.musicIntervalId = setInterval(() => {
            if (!CONFIG.musicEnabled || !this.ctx || Game.state !== 'PLAYING' || Game.paused) return;

            this.beatCount++;

            // MELODY - every 1/4 note
            if (this.beatCount % 2 === 0) {
                const idx = this.melodyPattern[this.melodyStep % this.melodyPattern.length];
                const freq = this.MELODY_SCALE[idx % this.MELODY_SCALE.length];
                this.playNote(freq, 'sine', 0.25, 0.12, this.musicGain);
                this.melodyStep++;
            }

            // BASS - every beat
            if (this.beatCount % 4 === 0) {
                const idx = this.bassPattern[this.bassStep % this.bassPattern.length];
                const freq = this.BASS_SCALE[idx % this.BASS_SCALE.length];
                this.playNote(freq, 'triangle', 0.45, 0.15, this.musicGain);
                this.bassStep++;
            }

            // CHORD - every 2 beats
            if (this.beatCount % 8 === 0) {
                const chordRoots = [261.63, 220.00, 246.94, 196.00];
                const root = chordRoots[(this.beatCount / 8) % chordRoots.length];
                this.playChord(root, 'sine', 0.8);
            }

            // KICK DRUM - every beat
            if (this.beatCount % 4 === 0) {
                this.playKick();
            }
            // HI-HAT - every 1/8 note
            this.playHiHat();

            // SNARE - on beats 2 and 4
            if (this.beatCount % 4 === 2) {
                this.playSnare();
            }
        }, eighthMs);
    },

    playKick() {
        if (!this.ctx) return;
        const osc = this.ctx.createOscillator();
        const g = this.ctx.createGain();
        osc.frequency.setValueAtTime(150, this.ctx.currentTime);
        osc.frequency.exponentialRampToValueAtTime(0.01, this.ctx.currentTime + 0.5);
        g.gain.setValueAtTime(0.8, this.ctx.currentTime);
        g.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + 0.5);
        osc.connect(g); g.connect(this.musicGain);
        osc.start(); osc.stop(this.ctx.currentTime + 0.5);
    },

    playSnare() {
        if (!this.ctx) return;
        const buffer = this.ctx.createBuffer(1, this.ctx.sampleRate * 0.15, this.ctx.sampleRate);
        const data = buffer.getChannelData(0);
        for (let i = 0; i < data.length; i++) data[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / data.length, 2);
        const src = this.ctx.createBufferSource();
        const g = this.ctx.createGain();
        g.gain.setValueAtTime(0.25, this.ctx.currentTime);
        g.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + 0.15);
        src.buffer = buffer;
        src.connect(g); g.connect(this.musicGain);
        src.start();
    },

    playHiHat() {
        if (!this.ctx) return;
        const buffer = this.ctx.createBuffer(1, this.ctx.sampleRate * 0.05, this.ctx.sampleRate);
        const data = buffer.getChannelData(0);
        for (let i = 0; i < data.length; i++) data[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / data.length, 3);
        const src = this.ctx.createBufferSource();
        const filter = this.ctx.createBiquadFilter();
        filter.type = 'highpass';
        filter.frequency.value = 8000;
        const g = this.ctx.createGain();
        g.gain.setValueAtTime(0.08, this.ctx.currentTime);
        g.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + 0.05);
        src.buffer = buffer;
        src.connect(filter); filter.connect(g); g.connect(this.musicGain);
        src.start();
    },

    // SFX
    playHit(quality, lane) {
        if (!CONFIG.soundEnabled || !this.ctx) return;
        // Musical notes based on lane
        const noteFreqs = [
            [523.25, 659.25],  // C5, E5
            [587.33, 739.99],  // D5, F#5
            [659.25, 783.99],  // E5, G5
            [783.99, 987.77]   // G5, B5
        ];
        const pair = noteFreqs[lane % 4];
        const freq = quality === 'PERFECT' ? pair[1] : pair[0];

        // Bell-like tone
        const osc1 = this.ctx.createOscillator();
        const osc2 = this.ctx.createOscillator();
        const g = this.ctx.createGain();
        osc1.type = 'sine';
        osc2.type = 'sine';
        osc1.frequency.setValueAtTime(freq, this.ctx.currentTime);
        osc2.frequency.setValueAtTime(freq * 2.76, this.ctx.currentTime); // Overtone
        osc2.frequency.exponentialRampToValueAtTime(freq * 2, this.ctx.currentTime + 0.4);

        const gainVal = quality === 'PERFECT' ? 0.5 : 0.35;
        g.gain.setValueAtTime(gainVal, this.ctx.currentTime);
        g.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + 0.5);

        osc1.connect(g); osc2.connect(g); g.connect(this.sfxGain);
        if (this.reverbNode) g.connect(this.reverbNode);
        osc1.start(); osc2.start();
        osc1.stop(this.ctx.currentTime + 0.5);
        osc2.stop(this.ctx.currentTime + 0.5);
    },

    playMiss() {
        if (!CONFIG.soundEnabled || !this.ctx) return;
        const osc = this.ctx.createOscillator();
        const g = this.ctx.createGain();
        osc.type = 'sawtooth';
        osc.frequency.setValueAtTime(220, this.ctx.currentTime);
        osc.frequency.exponentialRampToValueAtTime(55, this.ctx.currentTime + 0.4);
        g.gain.setValueAtTime(0.2, this.ctx.currentTime);
        g.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + 0.4);
        osc.connect(g); g.connect(this.sfxGain);
        osc.start(); osc.stop(this.ctx.currentTime + 0.4);
    },

    playStar() {
        if (!CONFIG.soundEnabled || !this.ctx) return;
        // Ascending arpeggio for combo milestone
        const notes = [523.25, 659.25, 783.99, 1046.50];
        notes.forEach((freq, i) => {
            setTimeout(() => {
                if (!this.ctx) return;
                const osc = this.ctx.createOscillator();
                const g = this.ctx.createGain();
                osc.type = 'sine';
                osc.frequency.value = freq;
                g.gain.setValueAtTime(0.3, this.ctx.currentTime);
                g.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + 0.2);
                osc.connect(g); g.connect(this.sfxGain);
                osc.start(); osc.stop(this.ctx.currentTime + 0.2);
            }, i * 80);
        });
    }
};

// ============================================================
// VFX CLASSES
// ============================================================
class FloatingText {
    constructor(x, y, text, color, size = 22) {
        this.x = x; this.y = y; this.text = text; this.color = color;
        this.life = 1.0; this.vy = -2.5;
        this.size = size;
    }
    update(deltaFrames = 1) {
        this.y += this.vy * deltaFrames;
        this.vy *= Math.pow(0.95, deltaFrames);
        this.life -= 0.025 * deltaFrames;
    }
    draw(ctx) {
        ctx.save();
        ctx.globalAlpha = Math.max(0, this.life);
        ctx.fillStyle = this.color;
        const sz = this.size + (1 - this.life) * 10;
        ctx.font = `bold ${sz}px Orbitron, sans-serif`;
        ctx.textAlign = 'center';
        // Optimized: Removed shadowBlur
        ctx.fillText(this.text, this.x, this.y);
        ctx.restore();
    }
}

class Particle {
    constructor(x, y, color) {
        this.x = x; this.y = y;
        this.size = Math.random() * 9 + 3;
        this.vx = (Math.random() - 0.5) * 16;
        this.vy = (Math.random() - 0.5) * 16;
        this.color = color;
        this.life = 1.0;
        this.decay = Math.random() * 0.03 + 0.015;
        this.rotation = Math.random() * Math.PI * 2;
        this.rotSpeed = (Math.random() - 0.5) * 0.3;
        this.shape = Math.random() < 0.5 ? 'circle' : 'star';
    }
    update(deltaFrames = 1) {
        this.x += this.vx * deltaFrames; this.y += this.vy * deltaFrames;
        this.vy += 0.3 * deltaFrames; // Gravity
        this.life -= this.decay * deltaFrames;
        this.size *= Math.pow(0.97, deltaFrames);
        this.rotation += this.rotSpeed * deltaFrames;
    }
    draw(ctx) {
        ctx.save();
        ctx.globalAlpha = Math.max(0, this.life);
        ctx.fillStyle = this.color;
        // Optimized: Removed shadowBlur
        ctx.translate(this.x, this.y);
        ctx.rotate(this.rotation);
        if (this.shape === 'star') {
            this.drawStar(ctx, 0, 0, this.size, this.size * 0.5, 5);
        } else {
            ctx.beginPath();
            ctx.arc(0, 0, this.size, 0, Math.PI * 2);
            ctx.fill();
        }
        ctx.restore();
    }
    drawStar(ctx, cx, cy, outerR, innerR, points) {
        ctx.beginPath();
        for (let i = 0; i < points * 2; i++) {
            const r = i % 2 === 0 ? outerR : innerR;
            const angle = (i * Math.PI) / points - Math.PI / 2;
            if (i === 0) ctx.moveTo(cx + r * Math.cos(angle), cy + r * Math.sin(angle));
            else ctx.lineTo(cx + r * Math.cos(angle), cy + r * Math.sin(angle));
        }
        ctx.closePath(); ctx.fill();
    }
}

class HitRipple {
    constructor(x, y, color) {
        this.x = x; this.y = y; this.color = color;
        this.life = 1.0; this.r = 5;
        this.lineWidth = 4;
    }
    update(deltaFrames = 1) {
        this.r += 12 * deltaFrames;
        this.life -= 0.06 * deltaFrames;
        this.lineWidth = Math.max(1, 4 * this.life);
    }
    draw(ctx) {
        ctx.save();
        ctx.globalAlpha = Math.max(0, this.life);
        ctx.strokeStyle = this.color;
        ctx.lineWidth = this.lineWidth;
        // Optimized: Removed shadowBlur
        ctx.beginPath(); ctx.arc(this.x, this.y, this.r, 0, Math.PI * 2); ctx.stroke();
        // Second ring
        ctx.globalAlpha = Math.max(0, this.life * 0.5);
        ctx.beginPath(); ctx.arc(this.x, this.y, this.r * 0.6, 0, Math.PI * 2); ctx.stroke();
        ctx.restore();
    }
}

class ShockWave {
    constructor(x, y, color) {
        this.x = x; this.y = y; this.color = color;
        this.life = 1.0; this.r = 0;
    }
    update(deltaFrames = 1) {
        this.r += 20 * deltaFrames;
        this.life -= 0.08 * deltaFrames;
    }
    draw(ctx) {
        ctx.save();
        ctx.globalAlpha = Math.max(0, this.life * 0.5);
        const grad = ctx.createRadialGradient(this.x, this.y, 0, this.x, this.y, this.r);
        grad.addColorStop(0, 'transparent');
        grad.addColorStop(0.7, this.color);
        grad.addColorStop(1, 'transparent');
        ctx.fillStyle = grad;
        ctx.beginPath(); ctx.arc(this.x, this.y, this.r, 0, Math.PI * 2); ctx.fill();
        ctx.restore();
    }
}



class Tile {
    constructor(speed, data, lane, laneMetrics, isLong = false) {
        this.lane = lane;
        this.w = laneMetrics.noteWidth;
        this.x = laneMetrics.noteX;
        this.speed = speed;
        this.data = data;
        this.isLong = isLong;
        this.length = isLong ? 170 + Math.random() * 80 : 112 + Math.random() * 26;
        this.y = -this.length - 90;
        this.isHit = false;
        this.hitAlpha = 1.0;
        this.imgObj = null;
        this.glowPulse = Math.random() * Math.PI * 2; // offset for pulsing glow
        this.color = CONFIG.colors[lane % CONFIG.colors.length];
        if (typeof data === 'string' && !data.startsWith('#')) {
            this.imgObj = new Image();
            this.imgObj.src = data;
        }
    }
    update(deltaFrames = 1) {
        if (!this.isHit) {
            this.y += this.speed * deltaFrames;
        } else {
            this.hitAlpha -= 0.15 * deltaFrames;
            this.length *= Math.max(0.72, 1 - 0.2 * deltaFrames); // Shrink effect like real piano tiles
            this.y += this.speed * 0.5 * deltaFrames;
            // Center the shrink roughly
            this.glowPulse += 0.3 * deltaFrames;
        }
        if (!this.isHit) this.glowPulse += 0.1 * deltaFrames;
    }
}

// ============================================================
// MAIN GAME OBJECT
// ============================================================
window.Game = {
    canvas: null, ctx: null, width: 0, height: 0,
    state: 'MENU', score: 0, combo: 0, maxCombo: 0, perfects: 0, level: 1, xp: 0,
    tiles: [], particles: [], fx: [], shake: 0,
    images: [], laneWidth: 0, spawnTimerMs: 0, spawnIntervalMs: 820, autoPlay: false,
    lives: 3, misses: 0, hits: 0, paused: false, revivesUsed: 0,
    startMs: 0, endMs: 0, difficulty: 'normal',
    flash: 0, bgHue: 0,
    isWebEnvironment: false,
    lastFrameTs: 0,
    patternStep: 0,
    patternIndex: 0,
    lastSpawnLane: 1,
    laneImpulses: [0, 0, 0, 0],

    init() {
        // Detect if running in web environment via flutter param
        this.isWebEnvironment = window.location.search.includes('isWeb=true') || !navigator.userAgent.includes('Android') && !navigator.userAgent.includes('iPhone');
        this.canvas = document.getElementById('game-canvas');
        this.ctx = this.canvas.getContext('2d');
        this.resize();
        window.addEventListener('resize', () => this.resize());
        window.addEventListener('message', (e) => {
            try {
                if (e.data === '{"action":"revive"}') {
                    if(window.Game) window.Game.revive();
                }
            } catch(err) {}
        });
        // FREE CLICK - just detect the lane, no accuracy requirement
        this.canvas.addEventListener('pointerdown', (e) => this.handleInput(e));
        this.loadUserData();
        this.loadImages();
        requestAnimationFrame(() => this.loop());
        UI.initShop();
        UI.initLives();
        UI.renderLeaderboard();
    },

    resize() {
        this.width = window.innerWidth;
        this.height = window.innerHeight;
        this.canvas.width = this.width;
        this.canvas.height = this.height;
        this.laneWidth = this.width / CONFIG.laneCount;
    },

    getDifficultyProfile() {
        return DIFFICULTY[this.difficulty] || DIFFICULTY.normal;
    },

    getLaneMetrics(lane) {
        const laneX = lane * this.laneWidth;
        const inset = Math.max(8, this.laneWidth * CONFIG.laneInsetRatio);
        const noteWidth = Math.max(40, this.laneWidth * CONFIG.laneNoteWidthRatio);
        const noteX = laneX + (this.laneWidth - noteWidth) / 2;
        return { laneX, inset, noteX, noteWidth };
    },

    getHitLineY() {
        return this.height * CONFIG.hitLineRatio;
    },

    getJudgePointY(tile) {
        return tile.y + Math.min(62, tile.length * 0.3);
    },

    chooseNextPattern() {
        let next = Math.floor(Math.random() * SPAWN_PATTERNS.length);
        if (SPAWN_PATTERNS.length > 1 && next === this.patternIndex) {
            next = (next + 1) % SPAWN_PATTERNS.length;
        }
        this.patternIndex = next;
        this.patternStep = 0;
    },

    resolveLaneConflict(preferredLane) {
        const laneOrder = [
            preferredLane,
            (preferredLane + 1) % CONFIG.laneCount,
            (preferredLane + CONFIG.laneCount - 1) % CONFIG.laneCount,
            (preferredLane + 2) % CONFIG.laneCount,
        ];

        for (const lane of laneOrder) {
            const nearestTile = this.tiles
                .filter((t) => !t.isHit && t.lane === lane)
                .sort((a, b) => a.y - b.y)[0];
            if (!nearestTile || nearestTile.y > this.height * 0.24) {
                return lane;
            }
        }

        return laneOrder.find((lane) => lane !== this.lastSpawnLane) ?? preferredLane;
    },

    async loadImages() {
        this.images = [];
        try {
            if (window.parent && window.parent.allFeeds) {
                Object.values(window.parent.allFeeds).forEach(f => {
                    if (f.img && f.visibility !== 'private') this.images.push(f.img);
                });
            }
            if (window.parent && window.parent.memoryData) {
                window.parent.memoryData.forEach(m => { if (m.url) this.images.push(m.url); });
            }
        } catch (e) {}
        if (this.images.length === 0) this.images = CONFIG.colors;
    },

    loadUserData() {
        const saved = localStorage.getItem('sr_data_v4');
        if (saved) {
            const data = JSON.parse(saved);
            this.level = data.level || 1;
            this.xp = data.xp || 0;
            this.difficulty = data.difficulty || 'normal';
            UI.updateXP();
        }
    },

    saveUserData() {
        localStorage.setItem('sr_data_v4', JSON.stringify({ level: this.level, xp: this.xp, difficulty: this.difficulty }));
    },

    start() {
        this.paused = false;
        this.state = 'PLAYING';
        this.score = 0; this.combo = 0; this.maxCombo = 0; this.perfects = 0;
        this.misses = 0; this.hits = 0;
        this.revivesUsed = 0;
        this.tiles = []; this.particles = []; this.fx = [];
        this.spawnTimerMs = 0;
        this.spawnCounter = 0;
        this.spawnIntervalMs = this.getDifficultyProfile().spawnIntervalMs;
        this.lives = this.getDifficultyProfile().missGrace ?? 3;
        this.startMs = performance.now();
        this.lastFrameTs = this.startMs;
        this.endMs = this.startMs + this.getDifficultyProfile().durationMs;
        this.patternIndex = 0;
        this.patternStep = 0;
        this.lastSpawnLane = 1;
        this.laneImpulses = [0, 0, 0, 0];
        this.chooseNextPattern();
        UI.updateLives();
        document.getElementById('menu-main').classList.add('hidden');
        document.getElementById('menu-over').classList.add('hidden');
        AudioEngine.init();
        UI.updateScore();
        UI.updateOverStats();
    },

    loop() {
        const now = performance.now();
        const deltaMs = this.lastFrameTs ? now - this.lastFrameTs : 16.67;
        this.lastFrameTs = now;
        const deltaFrames = Math.min(2.4, deltaMs / 16.6667);
        const ctx = this.ctx;
        // Dynamic background
        this.bgHue = (this.bgHue + 0.15 * deltaFrames) % 360;
        const bgGrad = ctx.createLinearGradient(0, 0, this.width, this.height);
        bgGrad.addColorStop(0, `hsl(${this.bgHue}, 60%, 4%)`);
        bgGrad.addColorStop(0.5, `hsl(${(this.bgHue + 60) % 360}, 40%, 3%)`);
        bgGrad.addColorStop(1, `hsl(${(this.bgHue + 120) % 360}, 50%, 5%)`);
        ctx.fillStyle = bgGrad;
        ctx.fillRect(0, 0, this.width, this.height);

        // Optimization: Removed starfield and nebula to fix lag on mobile
        // this.drawStarfield();
        // this.drawNebulaBackground();

        if (this.flash > 0) {
            ctx.globalAlpha = Math.min(0.4, this.flash);
            ctx.fillStyle = 'rgba(255,255,255,1)';
            ctx.fillRect(0, 0, this.width, this.height);
            ctx.globalAlpha = 1.0;
            this.flash *= Math.max(0.5, 1 - 0.18 * deltaFrames);
        }

        if (this.state === 'PLAYING' && !this.paused) this.updateGame(deltaMs, deltaFrames);

        ctx.save();
        if (this.shake > 0) {
            ctx.translate((Math.random() - 0.5) * this.shake, (Math.random() - 0.5) * this.shake);
            this.shake *= Math.max(0.55, 1 - 0.12 * deltaFrames);
        }

        this.drawLanes();
        this.drawTiles();
        this.drawParticles();
        this.drawFX();
        ctx.restore();

        requestAnimationFrame(() => this.loop());
    },

    starfield: null,
    drawStarfield() {
        const ctx = this.ctx;
        if (!this.starfield) {
            this.starfield = [];
            for (let i = 0; i < 120; i++) {
                this.starfield.push({
                    x: Math.random() * this.width, y: Math.random() * this.height,
                    s: Math.random() * 2 + 0.5,
                    v: Math.random() * 1.5 + 0.3,
                    hue: Math.floor(Math.random() * 360)
                });
            }
        }
        const warp = 1 + Math.min(this.combo * 0.04, 4);
        this.starfield.forEach(s => {
            s.y += s.v * warp;
            s.hue = (s.hue + 0.5) % 360;
            if (s.y > this.height) { s.y = 0; s.x = Math.random() * this.width; }
            ctx.fillStyle = `hsla(${s.hue}, 100%, 85%, 0.6)`;
            const len = warp > 2 ? s.s * warp * 2 : s.s;
            if (warp > 2) {
                ctx.fillRect(s.x, s.y, s.s, len);
            } else {
                ctx.beginPath(); ctx.arc(s.x, s.y, s.s, 0, Math.PI * 2); ctx.fill();
            }
        });
    },

    nebulaPts: null,
    drawNebulaBackground() {
        const ctx = this.ctx;
        if (!this.nebulaPts) {
            this.nebulaPts = [];
            for (let i = 0; i < 5; i++) {
                this.nebulaPts.push({ x: Math.random() * this.width, y: Math.random() * this.height, r: 80 + Math.random() * 120, hue: Math.floor(Math.random() * 360), phase: Math.random() * Math.PI * 2 });
            }
        }
        this.nebulaPts.forEach(n => {
            n.phase += 0.005;
            const alpha = 0.04 + Math.sin(n.phase) * 0.02;
            const grad = ctx.createRadialGradient(n.x, n.y, 0, n.x, n.y, n.r);
            grad.addColorStop(0, `hsla(${n.hue}, 100%, 70%, ${alpha})`);
            grad.addColorStop(1, 'transparent');
            ctx.fillStyle = grad;
            ctx.fillRect(0, 0, this.width, this.height);
        });
    },

    updateGame(deltaMs = 16.67, deltaFrames = 1) {
        const now = performance.now();
        const left = Math.max(0, this.endMs - now);
        const total = Math.max(1, this.endMs - this.startMs);
        const pct = (1 - left / total) * 100;
        const bar = document.getElementById('xp-bar');
        if (bar) bar.style.width = Math.min(100, Math.max(0, pct)) + '%';
        if (now >= this.endMs) { this.gameOver(true); return; }

        this.spawnTimerMs += deltaMs;
        while (this.spawnTimerMs >= this.spawnIntervalMs) {
            this.spawnTimerMs -= this.spawnIntervalMs;
            this.spawnTile();
            const profile = this.getDifficultyProfile();
            if (this.spawnCounter > 0 && this.spawnCounter % 6 === 0 && this.spawnIntervalMs > profile.spawnFloorMs) {
                this.spawnIntervalMs = Math.max(profile.spawnFloorMs, this.spawnIntervalMs - 18);
            }
        }

        for (let i = this.tiles.length - 1; i >= 0; i--) {
            const t = this.tiles[i];
            t.update(deltaFrames);
            if (this.autoPlay && !t.isHit && this.getJudgePointY(t) >= this.getHitLineY() - 10) this.hitTile(t, 'PERFECT');
            if (t.y > this.height && !t.isHit) {
                this.registerMiss(); this.tiles.splice(i, 1);
            } else if (t.isHit && t.hitAlpha <= 0) {
                this.tiles.splice(i, 1);
            }
        }

        this.particles.forEach((p, i) => { p.update(deltaFrames); if (p.life <= 0) this.particles.splice(i, 1); });
        this.fx.forEach((f, i) => { f.update(deltaFrames); if (f.life <= 0) this.fx.splice(i, 1); });
        this.laneImpulses = this.laneImpulses.map((value) => Math.max(0, value - 0.05 * deltaFrames));
    },

    spawnTile() {
        const profile = this.getDifficultyProfile();
        const visibleTiles = this.tiles.filter((tile) => !tile.isHit);
        if (visibleTiles.length >= profile.maxVisibleTiles) return;

        if (!SPAWN_PATTERNS[this.patternIndex] || this.patternStep >= SPAWN_PATTERNS[this.patternIndex].length) {
            this.chooseNextPattern();
        }

        let lane = SPAWN_PATTERNS[this.patternIndex][this.patternStep % SPAWN_PATTERNS[this.patternIndex].length];
        this.patternStep++;
        lane = this.resolveLaneConflict(lane);
        this.lastSpawnLane = lane;

        this.spawnCounter = (this.spawnCounter || 0) + 1;
        const mul = profile.speedMul ?? 1.0;
        const baseSpd = (CONFIG.baseSpeed + (this.score / 4500)) * mul;
        const data = this.images[Math.floor(Math.random() * this.images.length)];
        const isLong = Math.random() < (profile.longNoteChance ?? 0.07);
        this.tiles.push(new Tile(baseSpd, data, lane, this.getLaneMetrics(lane), isLong));
    },

    // STRICT CLICK - Must tap exactly on the tile or very close to it
    handleInput(e) {
        if (this.state !== 'PLAYING' || this.autoPlay) return;
        const rect = this.canvas.getBoundingClientRect();
        let clientX = e.clientX;
        let clientY = e.clientY;
        if (e.touches && e.touches.length > 0) {
            clientX = e.touches[0].clientX;
            clientY = e.touches[0].clientY;
        }
        
        const x = clientX - rect.left;
        const y = clientY - rect.top;
        const lane = Math.max(0, Math.min(CONFIG.laneCount - 1, Math.floor(x / this.laneWidth)));
        const hitLineY = this.getHitLineY();

        let targetTile = null;
        let lowestY = -9999;
        const judgeWindow = Math.max(110, this.height * 0.12);

        for (const t of this.tiles) {
            if (!t.isHit) {
                const isLaneMatch = t.lane === lane;
                const isInJudgeWindow = Math.abs(this.getJudgePointY(t) - hitLineY) <= judgeWindow;
                const isDirectTouch = x >= t.x - 28 && x <= t.x + t.w + 28 &&
                    y >= t.y - 32 && y <= t.y + t.length + 32;

                if ((isLaneMatch && isInJudgeWindow) || isDirectTouch) {
                    if (t.y > lowestY) {
                        lowestY = t.y;
                        targetTile = t;
                    }
                }
            }
        }

        if (targetTile) {
            const judgeDistance = Math.abs(this.getJudgePointY(targetTile) - hitLineY);
            const quality = judgeDistance <= 52 ? 'PERFECT' : 'GOOD';
            this.hitTile(targetTile, quality);
        } else {
            // Misclick in empty space
            this.registerMiss();
        }
    },

    hitTile(tile, quality) {
        tile.isHit = true;
        this.hits++;
        const base = quality === 'PERFECT' ? 120 : 70;
        const mult = 1 + Math.min(3, this.combo * 0.07);
        this.score += Math.floor(base * mult);
        this.combo++;
        if (this.combo > this.maxCombo) this.maxCombo = this.combo;

        // Combo milestones
        if (this.combo > 0 && this.combo % 10 === 0) {
            AudioEngine.playStar();
            this.flash = Math.max(this.flash, 0.25);
        }

        if (quality === 'PERFECT') {
            this.perfects++;
            this.shake = 10;
            this.flash = Math.max(this.flash, 0.18);
        } else {
            this.shake = 4;
        }

        this.xp += quality === 'PERFECT' ? 4 : 2;
        if (this.xp > this.level * 100) { this.level++; this.xp = 0; }

        UI.updateScore(); UI.updateCombo(); UI.updateXP(); UI.updateOverStats();
        this.laneImpulses[tile.lane] = 1;
        AudioEngine.playHit(quality, tile.lane);
        if (CONFIG.vibrationEnabled && navigator.vibrate) navigator.vibrate(quality === 'PERFECT' ? 20 : 10);

        const lx = tile.x + tile.w / 2;
        const ly = tile.y + tile.length / 2;

        // Spawn rich VFX
        this.fx.push(new FloatingText(lx, ly - 60, quality, quality === 'PERFECT' ? '#ffd700' : '#00e5ff', quality === 'PERFECT' ? 28 : 22));
        this.fx.push(new HitRipple(lx, ly, tile.color));
        this.fx.push(new ShockWave(lx, ly, tile.color));
        
        const n = quality === 'PERFECT' ? 36 : 20;
        for (let i = 0; i < n; i++) {
            this.particles.push(new Particle(lx, ly, tile.color));
        }
    },



    drawTiles() {
        const ctx = this.ctx;
        this.tiles.forEach(t => {
            const x = t.x;
            const w = t.w;
            ctx.globalAlpha = t.hitAlpha;
            ctx.save();
            ctx.beginPath();
            const br = 16;
            ctx.roundRect(x, t.y, w, t.length, [br, br, 10, 10]);
            
            if (t.imgObj && t.imgObj.complete && t.imgObj.naturalWidth > 0) {
                ctx.save();
                ctx.clip();
                const img = t.imgObj;
                const iW = w; const iH = t.length;
                const ratio = img.width / img.height;
                if (ratio > iW / iH) {
                    ctx.drawImage(img, (img.width - img.height * (iW / iH)) / 2, 0, img.height * (iW / iH), img.height, x, t.y, iW, iH);
                } else {
                    ctx.drawImage(img, 0, (img.height - img.width * (iH / iW)) / 2, img.width, img.width * (iH / iW), x, t.y, iW, iH);
                }
                ctx.fillStyle = 'rgba(0,0,0,0.15)';
                ctx.fillRect(x, t.y, iW, iH);
                ctx.restore();
            } else {
                const grad = ctx.createLinearGradient(x, t.y, x, t.y + t.length);
                grad.addColorStop(0, t.color);
                grad.addColorStop(0.65, `${t.color}dd`);
                grad.addColorStop(1, '#111');
                ctx.fillStyle = grad;
                ctx.fill();
            }

            // Hit flash
            if (t.isHit) {
                ctx.fillStyle = `rgba(255, 255, 255, ${t.hitAlpha})`;
                ctx.fill();
                ctx.strokeStyle = '#fff';
            } else {
                ctx.strokeStyle = t.color;
            }

            // Neon stroke (removed laggy shadowBlur)
            ctx.lineWidth = t.isHit ? 5 : 2.5;
            ctx.stroke();

            if (!t.isHit) {
                const shine = ctx.createLinearGradient(x, t.y, x, t.y + t.length * 0.45);
                shine.addColorStop(0, 'rgba(255,255,255,0.24)');
                shine.addColorStop(1, 'rgba(255,255,255,0)');
                ctx.fillStyle = shine;
                ctx.fill();
            }

            ctx.restore();
        });
    },

    drawLanes() {
        const ctx = this.ctx;
        const hitLineY = this.getHitLineY();

        for (let lane = 0; lane < CONFIG.laneCount; lane++) {
            const metrics = this.getLaneMetrics(lane);
            const laneGlow = this.laneImpulses[lane];
            const grad = ctx.createLinearGradient(0, 0, 0, this.height);
            grad.addColorStop(0, 'rgba(255,255,255,0.015)');
            grad.addColorStop(0.55, 'rgba(255,255,255,0.035)');
            grad.addColorStop(1, 'rgba(255,255,255,0.075)');
            ctx.fillStyle = grad;
            ctx.fillRect(metrics.laneX, 0, this.laneWidth, this.height);

            if (laneGlow > 0) {
                const pulse = ctx.createLinearGradient(0, hitLineY - 120, 0, hitLineY + 80);
                pulse.addColorStop(0, 'rgba(255,255,255,0)');
                pulse.addColorStop(0.5, `${CONFIG.colors[lane]}33`);
                pulse.addColorStop(1, 'rgba(255,255,255,0)');
                ctx.fillStyle = pulse;
                ctx.fillRect(metrics.laneX, hitLineY - 120, this.laneWidth, 220);
            }

            if (lane < CONFIG.laneCount - 1) {
                ctx.fillStyle = 'rgba(255,255,255,0.07)';
                ctx.fillRect(metrics.laneX + this.laneWidth - 1, 0, 2, this.height);
            }

            const lineWidth = metrics.noteWidth;
            const lineX = metrics.noteX;
            const lineGrad = ctx.createLinearGradient(lineX, hitLineY, lineX + lineWidth, hitLineY);
            lineGrad.addColorStop(0, `${CONFIG.colors[lane]}55`);
            lineGrad.addColorStop(0.5, laneGlow > 0 ? `${CONFIG.colors[lane]}ff` : 'rgba(255,255,255,0.9)');
            lineGrad.addColorStop(1, `${CONFIG.colors[lane]}55`);
            ctx.fillStyle = lineGrad;
            ctx.beginPath();
            ctx.roundRect(lineX, hitLineY, lineWidth, 7, 999);
            ctx.fill();
        }
    },

    drawParticles() { this.particles.forEach(p => p.draw(this.ctx)); },
    drawFX() { this.fx.forEach(f => f.draw(this.ctx)); },

    toggleFullscreen() {
        if (!document.fullscreenElement) {
            document.documentElement.requestFullscreen().catch(e => console.warn(e));
        } else {
            document.exitFullscreen();
        }
    },
    toggleSound(v) { CONFIG.soundEnabled = v; },
    toggleMusic(v) {
        CONFIG.musicEnabled = v;
        if (!v && AudioEngine.ctx) {
            AudioEngine.musicGain.gain.setTargetAtTime(0, AudioEngine.ctx.currentTime, 0.2);
        } else if (v && AudioEngine.ctx) {
            AudioEngine.musicGain.gain.setTargetAtTime(0.35, AudioEngine.ctx.currentTime, 0.2);
        }
    },
    toggleVibration(v) { CONFIG.vibrationEnabled = v; },
    toggleAutoPlay(v) { this.autoPlay = !!v; },
    setDifficulty(d) {
        if (!DIFFICULTY[d]) return;
        this.difficulty = d;
        this.saveUserData();
        UI.toast(`Difficulty: ${d.toUpperCase()}`);
    },
    reset() { this.start(); },
    togglePause() {
        if (this.state !== 'PLAYING') return;
        this.paused = !this.paused;
        const btn = document.getElementById('btn-pause');
        if (btn) btn.innerHTML = this.paused ? '<i class="fa-solid fa-play"></i>' : '<i class="fa-solid fa-pause"></i>';
        if (!this.paused && AudioEngine.ctx && AudioEngine.ctx.state === 'suspended') AudioEngine.ctx.resume().catch(() => null);
    },
    exitToApp() {
        try { if (document.fullscreenElement) document.exitFullscreen().catch(() => null); } catch (e) {}
        try {
            if (window.parent && window.parent !== window && typeof window.parent.postMessage === 'function') {
                window.parent.postMessage('soul_game_close', '*'); return;
            }
        } catch (e) {}
        try {
            if (window.parent && window.parent !== window && typeof window.parent.closeGameModal === 'function') {
                window.parent.closeGameModal(); return;
            }
        } catch (e) {}
        try { window.location.href = '../../index.html'; } catch (e) {}
    },
    registerMiss() {
        this.combo = 0;
        this.misses++;
        this.lives = Math.max(0, this.lives - 1);
        this.shake = 12;
        AudioEngine.playMiss();
        if (CONFIG.vibrationEnabled && navigator.vibrate) navigator.vibrate([30, 20, 30]);
        UI.updateCombo(); UI.updateLives(); UI.updateOverStats();
        if (this.lives <= 0) this.gameOver(false);
    },
    gameOver(won) {
        if (this.state !== 'PLAYING') return;
        this.state = 'OVER';
        this.saveUserData();
        UI.saveScore(this.score);
        UI.renderLeaderboard();
        const t = document.getElementById('over-title');
        if (t) t.innerText = won ? '✨ COMPLETED' : '💔 FAILED';
        document.getElementById('final-score').innerText = this.score;
        document.getElementById('stat-perfect').innerText = this.perfects;
        document.getElementById('stat-miss').innerText = this.misses;
        UI.updateOverStats();
        
        const btnRevive = document.getElementById('btn-revive');
        if (btnRevive) {
            if (won) {
                btnRevive.style.display = 'none';
            } else {
                const maxRevives = this.isWebEnvironment ? 1 : 3;
                if ((this.revivesUsed || 0) < maxRevives) {
                    btnRevive.style.display = 'inline-block';
                    btnRevive.innerText = this.isWebEnvironment ? '🎬 HỒI SINH MIỄN PHÍ' : `🎬 HỒI SINH (XEM QC) [${(this.revivesUsed || 0)}/3]`;
                } else {
                    btnRevive.style.display = 'none';
                }
            }
        }
        
        document.getElementById('menu-over').classList.remove('hidden');
    },
    requestRevive() {
        try {
            if (window.parent && window.parent !== window && typeof window.parent.postMessage === 'function') {
                window.parent.postMessage('soul_game_request_revive', '*');
                return;
            }
            if (window.parent && window.parent !== window && typeof window.parent.requestGameRevive === 'function') {
                window.parent.requestGameRevive();
                return;
            }
            // For testing local:
            setTimeout(() => this.revive(), 500);
        } catch(e) {}
    },
    revive() {
        this.revivesUsed = (this.revivesUsed || 0) + 1;
        this.lives = DIFFICULTY[this.difficulty]?.missGrace ?? 3;
        this.state = 'PLAYING';
        UI.updateLives();
        document.getElementById('menu-over').classList.add('hidden');
        this.paused = false;
        
        // Remove tiles that are on bottom to prevent instant re-death
        for (let i = this.tiles.length - 1; i >= 0; i--) {
            if (this.tiles[i].y > this.height - 300) {
                this.tiles.splice(i, 1);
            }
        }
        
        this.shake = 0;
        this.laneImpulses = [0, 0, 0, 0];
    }
};

window.UI = {
    updateScore() {
        const el = document.getElementById('score-display');
        if (el) el.innerText = Game.score.toLocaleString();
    },
    updateCombo() {
        const el = document.getElementById('combo-display');
        document.getElementById('combo-num').innerText = Game.combo;
        if (Game.combo > 3) {
            el.classList.add('show');
            el.style.transform = 'scale(1.4)';
            setTimeout(() => el.style.transform = 'scale(1)', 120);
        } else el.classList.remove('show');
    },
    updateXP() {
        document.getElementById('level-display').innerText = Game.level;
        const pct = (Game.xp / (Game.level * 100)) * 100;
        const bar = document.getElementById('xp-bar');
        if (Game.state !== 'PLAYING' && bar) bar.style.width = pct + '%';
    },
    initLives() {
        const row = document.getElementById('lives-row');
        if (!row) return;
        row.innerHTML = '';
        for (let i = 0; i < 5; i++) {
            const d = document.createElement('div');
            d.className = 'life';
            row.appendChild(d);
        }
        this.updateLives();
    },
    updateLives() {
        const row = document.getElementById('lives-row');
        if (!row) return;
        const els = Array.from(row.children);
        const max = Math.min(5, DIFFICULTY[Game.difficulty]?.missGrace ?? 3);
        els.forEach((el, idx) => {
            el.style.display = idx < max ? 'block' : 'none';
            if (idx < max) el.classList.toggle('on', idx < Game.lives);
        });
    },
    updateOverStats() {
        const total = Math.max(1, Game.hits + Game.misses);
        const acc = Math.round((Game.hits / total) * 100);
        const grade = acc >= 95 && Game.misses === 0 ? 'S' : acc >= 90 ? 'A' : acc >= 80 ? 'B' : acc >= 70 ? 'C' : 'D';
        const elAcc = document.getElementById('stat-acc');
        const elGrade = document.getElementById('stat-grade');
        const elMiss = document.getElementById('stat-miss');
        if (elAcc) elAcc.innerText = acc + '%';
        if (elGrade) elGrade.innerText = grade;
        if (elMiss) elMiss.innerText = Game.misses;
    },
    initShop() {
        const grid = document.getElementById('shop-grid');
        if (!grid) return;
        grid.innerHTML = '';
        const SKINS = [
            { id: 'neon',   n: '🔥 Neon',   p: '#ff0055', s: '#00e5ff', colors: ['#ff0055','#00e5ff','#ffeb3b','#76ff03'] },
            { id: 'cyber',  n: '🌸 Sakura', p: '#ff4da6', s: '#ff9ef0', colors: ['#ff4da6','#ff9ef0','#ffb3d9','#ff69b4'] },
            { id: 'gold',   n: '🌟 Galaxy', p: '#7c4dff', s: '#e040fb', colors: ['#7c4dff','#e040fb','#00e5ff','#ffd700'] },
            { id: 'mint',   n: '🍀 Forest', p: '#00c853', s: '#69ff47', colors: ['#00c853','#69ff47','#00e5ff','#ffd700'] }
        ];
        const active = localStorage.getItem('sr_skin_v4') || 'neon';
        const applySkin = (skin) => {
            localStorage.setItem('sr_skin_v4', skin.id);
            document.documentElement.style.setProperty('--primary', skin.p);
            document.documentElement.style.setProperty('--secondary', skin.s);
            CONFIG.colors = skin.colors;
        };
        const current = SKINS.find(s => s.id === active) || SKINS[0];
        applySkin(current);
        SKINS.forEach(s => {
            const d = document.createElement('div');
            d.className = 'shop-item';
            if (s.id === active) d.classList.add('active');
            d.innerHTML = `<div style="font-size:28px;margin-bottom:6px;">${s.n.split(' ')[0]}</div><div style="font-size:12px;">${s.n.split(' ')[1]}</div>`;
            d.style.borderColor = s.p;
            d.onclick = () => {
                document.querySelectorAll('.shop-item').forEach(x => x.classList.remove('active'));
                d.classList.add('active');
                applySkin(s);
                this.toast(`Skin: ${s.n}`);
            };
            grid.appendChild(d);
        });
    },
    togglePanel(id) {
        const p = document.getElementById(id);
        const isOpen = p.classList.contains('open');
        this.closePanels();
        if (!isOpen) p.classList.add('open');
    },
    closePanels() { document.querySelectorAll('.panel').forEach(p => p.classList.remove('open')); },
    showHome() {
        document.getElementById('menu-over').classList.add('hidden');
        document.getElementById('menu-main').classList.remove('hidden');
        Game.state = 'MENU';
    },
    toast(msg) {
        Game.fx.push(new FloatingText(Game.width / 2, Game.height * 0.35, msg, '#ffffff', 20));
    },
    saveScore(score) {
        try {
            const key = 'sr_lb_v4';
            const list = JSON.parse(localStorage.getItem(key) || '[]');
            list.push({ score, t: Date.now(), d: Game.difficulty, acc: Math.round((Game.hits / Math.max(1, Game.hits + Game.misses)) * 100) });
            list.sort((a, b) => b.score - a.score);
            localStorage.setItem(key, JSON.stringify(list.slice(0, 15)));
        } catch (e) {}
    },
    renderLeaderboard() {
        const el = document.getElementById('lb-list');
        if (!el) return;
        let list = [];
        try { list = JSON.parse(localStorage.getItem('sr_lb_v4') || '[]'); } catch (e) { list = []; }
        if (!Array.isArray(list) || list.length === 0) {
            el.innerHTML = `<div style="text-align:center; padding: 20px; color:#666;">Chưa có điểm. Chơi một ván để lưu kỷ lục.</div>`;
            return;
        }
        const medal = ['🥇','🥈','🥉'];
        el.innerHTML = list.slice(0, 10).map((it, idx) => {
            const d = (it && it.d ? String(it.d).toUpperCase() : 'N/A');
            const a = (it && typeof it.acc === 'number' ? it.acc + '%' : '--');
            const rank = medal[idx] || `#${idx + 1}`;
            return `<div class="lb-item"><div class="lb-rank">${rank}</div><div style="flex:1;text-align:left;padding-left:8px;color:#bbb;">${d} • ${a}</div><div class="lb-score">${it.score.toLocaleString()}</div></div>`;
        }).join('');
    }
};

window.onload = () => Game.init();
