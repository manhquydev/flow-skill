# Task service. Implements FR1 (create + list) only.
# FR2 (mark a task done) has no route here - the done endpoint was never written.
tasks = []

def create_task(title):
    t = {"id": len(tasks) + 1, "title": title, "done": False}
    tasks.append(t)
    return t

def list_tasks():
    return tasks
