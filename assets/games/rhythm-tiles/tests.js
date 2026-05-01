
// Simple Test Suite for Game Logic
const tests = {
    testParticleSystem: () => {
        const p = new Particle(100, 100, 'red');
        console.assert(p.x === 100, 'Particle X init failed');
        console.assert(p.life === 1.0, 'Particle life init failed');
        p.update();
        console.assert(p.life < 1.0, 'Particle update failed');
        return true;
    },
    testTileLogic: () => {
        const t = new Tile(0, 5, null);
        console.assert(t.y === -200, 'Tile Y init failed');
        t.update();
        console.assert(t.y === -195, 'Tile move failed');
        return true;
    },
    testGameInit: () => {
        // Mock DOM
        document.body.innerHTML = '<canvas id="game-canvas"></canvas><div id="shop-grid"></div>';
        try {
            Game.init();
            console.assert(Game.state === 'MENU', 'Game state init failed');
            return true;
        } catch(e) {
            console.error(e);
            return false;
        }
    }
};

// Run Tests
console.log("Running Game Tests...");
Object.keys(tests).forEach(t => {
    try {
        if(tests[t]()) console.log(`✅ ${t} Passed`);
        else console.error(`❌ ${t} Failed`);
    } catch(e) {
        console.error(`❌ ${t} Error:`, e);
    }
});
