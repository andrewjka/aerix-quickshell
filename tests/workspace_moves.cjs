// Exercise the actual QML service methods with a deterministic compositor model.
const { readFileSync } = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = readFileSync(`${__dirname}/../services/WorkspaceService.qml`, 'utf8');
const methods = [...source.matchAll(/^    function [\s\S]*?^    }/gm)].map(m => m[0]).join('\n');
function fixture(lua = false) {
    const calls = [];
    const liveRequests = [];
    const ctx = {
        toplevels: [{ address: 'abc', workspace: { id: 1 } },
            { address: '0xdef', workspace: { id: 1 } },
            { address: '123', workspace: { id: 2 } }],
        moveQueue: [], currentMove: null, operationError: '', moveDeadline: 0,
        Hyprland: { usingLua: lua, dispatch: command => calls.push(command), refreshToplevels() {} },
        previewLiveRequested: workspaceIds => liveRequests.push([...workspaceIds])
    };
    Object.defineProperty(ctx, 'busy', { get: () => ctx.currentMove !== null || ctx.moveQueue.length > 0 });
    vm.createContext(ctx);
    vm.runInContext(methods, ctx);
    // Queue tests do not model asynchronous compositor metadata updates.
    ctx.refreshSlots = () => {};
    function confirm() {
        const step = ctx.currentMove;
        ctx.windowForAddress(step.address).workspace.id = step.to;
        ctx.advanceMove();
    }
    return { ctx, calls, liveRequests, confirm };
}
{
    const ctx = { toplevels: [], workspaces: [], slots: [] };
    vm.createContext(ctx);
    vm.runInContext(methods, ctx);
    for (let id = 1; id <= 10; id++) {
        ctx.workspaces.push({ id, monitor: { name: 'test' } });
        ctx.slots.push({ workspaceId: id, windows: [] });
    }
    ctx.toplevels = [1, 2, 3].map(id => ({
        address: String(id), workspace: ctx.workspaces[id - 1]
    }));
    ctx.refreshSlots();
    const before = ctx.slots.map(slot => slot.windows);
    ctx.toplevels[0].workspace = ctx.workspaces[1];
    ctx.refreshSlots();
    assert.notEqual(ctx.slots[0].windows, before[0]);
    assert.notEqual(ctx.slots[1].windows, before[1]);
    for (let i = 2; i < 10; i++) assert.equal(ctx.slots[i].windows, before[i]);
    const after = ctx.slots.map(slot => slot.windows);
    ctx.refreshSlots();
    ctx.slots.forEach((slot, i) => assert.equal(slot.windows, after[i]));
}
for (const lua of [false, true]) {
    const { ctx, calls, liveRequests, confirm } = fixture(lua);
    assert.equal(ctx.normalizedAddress('ABC'), '0xabc');
    assert.equal(ctx.normalizedAddress('0XABC'), '0xabc');
    assert.equal(ctx.sameWindows([{ address: 'abc' }], [{ address: '0xABC' }]), true,
        'a fresh Hyprland wrapper for the same window must not replace a card model');
    assert.equal(ctx.sameWindows([{ address: 'abc' }], [{ address: 'def' }]), false);
    const oldHandle = {};
    assert.equal(ctx.sameWindows([{ address: 'abc', wayland: oldHandle }],
        [{ address: '0xABC', wayland: {} }]), false,
    'a changed Wayland export handle must replace the affected card model');
    assert.equal(ctx.moveWindow('invalid', 2), false);
    assert.equal(ctx.moveWindow('abc', 10), true);
    assert.deepEqual([...ctx.activeMoveWorkspaceIds].sort(), [1, 10]);
    assert.deepEqual(liveRequests[0].sort(), [1, 10]);
    assert.match(calls[0], /address:0xabc/);
    assert.equal(ctx.moveWindow('123', 3), false, 'busy queue must reject a second operation');
    confirm();
    assert.equal(ctx.toplevels[0].workspace.id, 10);
    assert.equal(ctx.busy, false);
    assert.deepEqual([...ctx.activeMoveWorkspaceIds], []);
    assert.deepEqual(liveRequests.at(-1).sort(), [1, 10]);
}
{
    const { ctx, calls, confirm } = fixture();
    assert.equal(ctx.swapWorkspaces({ workspaceId: 1 }, { workspaceId: 2 }), true);
    assert.equal(calls.length, 1, 'wait for each confirmation');
    while (ctx.busy) confirm();
    assert.deepEqual(ctx.toplevels.map(w => w.workspace.id), [2, 2, 1]);
    assert.equal(calls.length, 3, 'move each original window exactly once');
    ctx.swapWorkspaces({ workspaceId: 2 }, { workspaceId: 10 });
    while (ctx.busy) confirm();
    assert.deepEqual(ctx.toplevels.map(w => w.workspace.id), [10, 10, 1]);
}
{
    const { ctx, calls, confirm } = fixture();
    ctx.swapWorkspaces({ workspaceId: 1 }, { workspaceId: 2 });
    ctx.toplevels[1].workspace.id = 5;
    confirm();
    assert.equal(ctx.busy, false);
    assert.notEqual(ctx.operationError, '');
    assert.equal(calls.length, 1, 'do not move a window that changed workspace externally');
}
console.log('PASS: address normalization, Lua/legacy moves, busy guard, swap, empty target, interrupted queue');
