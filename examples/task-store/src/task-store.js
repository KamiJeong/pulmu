export class TaskStore {
  #tasks = [];

  add(title) {
    const task = {
      id: this.#tasks.length + 1,
      title,
      completed: false,
    };
    this.#tasks.push(task);
    return task;
  }

  list() {
    return this.#tasks.map((task) => ({ ...task }));
  }
}
