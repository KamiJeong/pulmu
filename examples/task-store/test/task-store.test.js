import test from 'node:test';
import assert from 'node:assert/strict';
import { TaskStore } from '../src/task-store.js';

test('add stores an incomplete task', () => {
  const store = new TaskStore();
  const task = store.add('forge it');

  assert.equal(task.id, 1);
  assert.equal(task.title, 'forge it');
  assert.equal(task.completed, false);
  assert.deepEqual(store.list(), [task]);
});
