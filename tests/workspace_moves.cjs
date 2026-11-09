// Exercise the actual QML service methods with a deterministic compositor model.
const { readFileSync } = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = readFileSync(`${__dirname}/../services/WorkspaceService.qml`, 'utf8');
const methods = [...source.matchAll(/^    function [\s\S]*?^    }/gm)].map(m => m[0]).join('\n');
function fixture(lua = false) {
    const calls = [];
    const ctx = {
        toplevels: [{ address: 'abc', workspace: { id: 1 } },
            { address: '0xdef', workspace: { id: 1 } },
            { address: '123', workspace: { id: 2 } }],
        moveQueue: [], currentMove: null, operationError: '', moveDeadline: 0,
        previewRevisions: {}, affectedWorkspaces: [],
        Hyprland: { usingLua: lua, dispatch: command => calls.push(command), refreshToplevels() {} }
    };
    Object.defineProperty(ctx, 'busy', { get: () => ctx.currentMove !== null || ctx.moveQueue.length > 0 });
    vm.createContext(ctx);
    vm.runInContext(methods, ctx);
    function confirm() {
        const step = ctx.currentMove;
        ctx.windowForAddress(step.address).workspace.id = step.to;
        ctx.advanceMove();
    }
    return { ctx, calls, confirm };
}
for (const lua of [false, true]) {
    const { ctx, calls, confirm } = fixture(lua);
    assert.equal(ctx.normalizedAddress('ABC'), '0xabc');
    assert.equal(ctx.normalizedAddress('0XABC'), '0xabc');
    assert.equal(ctx.moveWindow('invalid', 2), false);
    assert.equal(ctx.moveWindow('abc', 10), true);
    assert.match(calls[0], /address:0xabc/);
    assert.equal(ctx.moveWindow('123', 3), false, 'busy queue must reject a second operation');
    confirm();
    assert.equal(ctx.toplevels[0].workspace.id, 10);
    assert.equal(ctx.busy, false);
}
{
    const { ctx, calls, confirm } = fixture();
    assert.equal(ctx.swapWorkspaces({ workspaceId: 1 }, { workspaceId: 2 }), true);
    assert.equal(calls.length, 1, 'wait for each confirmation');
    while (ctx.busy) confirm();
    assert.deepEqual(ctx.toplevels.map(w => w.workspace.id), [2, 2, 1]);
    assert.equal(calls.length, 3, 'move each original window exactly once');
    assert.equal(ctx.previewRevisions[1], 1);
    assert.equal(ctx.previewRevisions[2], 1);
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
