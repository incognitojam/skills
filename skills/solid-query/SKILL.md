---
name: solid-query
description: TanStack Solid Query patterns — options as a function, never destructuring results, reading signals inside options, dependent queries, mutations with optimistic updates, query key factories, and staleTime versus gcTime. Use when writing or reviewing `@tanstack/solid-query` code, or when a query does not refetch as expected. React Query habits break here; for core Solid reactivity see the solidjs-v2 skill.
---

# TanStack Solid Query

## Quick Reference

| React Query | Solid Query | Notes |
|-------------|-------------|-------|
| `useQuery({ ... })` | `createQuery(() => ({ ... }))` | Options wrapped in function |
| `const { data } = useQuery()` | `const query = createQuery()` | Never destructure |
| `data` | `query.data` | Access on store object |
| `queryKey: ['todos', filter]` | `queryKey: ['todos', filter()]` | Call signals inside |
| `enabled: !!user` | `enabled: !!user()` | Reactive with signals |
| `QueryErrorResetBoundary` | Native `<ErrorBoundary>` | Use Solid's built-in |

## Critical Patterns

### Options Must Be a Function

```tsx
// WRONG - React style
createQuery({
  queryKey: ['todos'],
  queryFn: fetchTodos,
});

// CORRECT - Solid style
createQuery(() => ({
  queryKey: ['todos'],
  queryFn: fetchTodos,
}));
```

### Never Destructure Results

```tsx
// WRONG - Breaks reactivity
const { data, isLoading, error } = createQuery(...);

// CORRECT - Access on store
const query = createQuery(() => ({
  queryKey: ['todos'],
  queryFn: fetchTodos,
}));

// Use: query.data, query.isLoading, query.error
```

### Signals Work Inside Options

```tsx
const [filter, setFilter] = createSignal('all');
const [userId, setUserId] = createSignal(1);

const query = createQuery(() => ({
  queryKey: ['todos', filter(), userId()],  // Reactive!
  queryFn: () => fetchTodos(filter(), userId()),
  enabled: userId() > 0,  // Reactive!
}));
```

## Setup

```tsx
import { QueryClient, QueryClientProvider } from '@tanstack/solid-query';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5,  // 5 minutes
      gcTime: 1000 * 60 * 60,    // 1 hour (formerly cacheTime)
    },
  },
});

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <MyApp />
    </QueryClientProvider>
  );
}
```

## Query Patterns

### Basic Query with States

```tsx
import { Match, Switch } from 'solid-js';

function TodoList() {
  const query = createQuery(() => ({
    queryKey: ['todos'],
    queryFn: async () => {
      const res = await fetch('/api/todos');
      if (!res.ok) throw new Error('Failed');
      return res.json();
    },
  }));

  return (
    <Switch>
      <Match when={query.isPending}>Loading...</Match>
      <Match when={query.error}>Error: {query.error.message}</Match>
      <Match when={query.data}>
        <For each={query.data}>{todo => <TodoItem todo={todo} />}</For>
      </Match>
    </Switch>
  );
}
```

### Dependent Queries

```tsx
function UserTodos(props) {
  const userQuery = createQuery(() => ({
    queryKey: ['user', props.userId],
    queryFn: () => fetchUser(props.userId),
  }));

  const todosQuery = createQuery(() => ({
    queryKey: ['todos', userQuery.data?.id],
    queryFn: () => fetchTodos(userQuery.data.id),
    enabled: !!userQuery.data?.id,  // Only runs when user loaded
  }));

  return <Show when={todosQuery.data}>{/* ... */}</Show>;
}
```

### Suspense Integration

```tsx
function App() {
  return (
    <Suspense fallback={<Loading />}>
      <TodoList />
    </Suspense>
  );
}

function TodoList() {
  const query = createQuery(() => ({
    queryKey: ['todos'],
    queryFn: fetchTodos,
  }));

  // Accessing query.data inside Suspense triggers suspension
  return <For each={query.data}>{todo => <div>{todo.title}</div>}</For>;
}
```

## Mutations

### Basic Mutation

```tsx
import { createMutation, useQueryClient } from '@tanstack/solid-query';

function CreateTodo() {
  const queryClient = useQueryClient();

  const mutation = createMutation(() => ({
    mutationFn: (newTodo) =>
      fetch('/api/todos', {
        method: 'POST',
        body: JSON.stringify(newTodo),
      }).then(r => r.json()),

    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['todos'] });
    },
  }));

  return (
    <button
      onClick={() => mutation.mutate({ title: 'New Todo' })}
      disabled={mutation.isPending}
    >
      {mutation.isPending ? 'Creating...' : 'Create'}
    </button>
  );
}
```

### Optimistic Updates

```tsx
const mutation = createMutation(() => ({
  mutationFn: updateTodo,
  onMutate: async (newTodo) => {
    await queryClient.cancelQueries({ queryKey: ['todos'] });
    const previous = queryClient.getQueryData(['todos']);

    queryClient.setQueryData(['todos'], (old) =>
      old.map(t => t.id === newTodo.id ? newTodo : t)
    );

    return { previous };
  },
  onError: (err, newTodo, context) => {
    queryClient.setQueryData(['todos'], context.previous);
  },
  onSettled: () => {
    queryClient.invalidateQueries({ queryKey: ['todos'] });
  },
}));
```

## Query Keys

### Factory Pattern

```tsx
// lib/queries.ts
export const queryKeys = {
  todos: {
    all: ['todos'] as const,
    lists: () => [...queryKeys.todos.all, 'list'] as const,
    list: (filters: Filters) => [...queryKeys.todos.lists(), filters] as const,
    details: () => [...queryKeys.todos.all, 'detail'] as const,
    detail: (id: number) => [...queryKeys.todos.details(), id] as const,
  },
  users: {
    all: ['users'] as const,
    detail: (id: number) => [...queryKeys.users.all, id] as const,
  },
};

// Usage
createQuery(() => ({
  queryKey: queryKeys.todos.detail(props.id),
  queryFn: () => fetchTodo(props.id),
}));

// Invalidation
queryClient.invalidateQueries({ queryKey: queryKeys.todos.lists() });
```

## Caching

### staleTime vs gcTime

| Option | Default | Purpose |
|--------|---------|---------|
| `staleTime` | 0 | How long data is "fresh" (no background refetch) |
| `gcTime` | 5 min | How long inactive data stays in cache |

```tsx
// Data rarely changes - keep fresh longer
createQuery(() => ({
  queryKey: ['user-profile'],
  queryFn: fetchProfile,
  staleTime: 1000 * 60 * 10,  // 10 minutes
}));

// Never auto-refetch (manual only)
createQuery(() => ({
  queryKey: ['config'],
  queryFn: fetchConfig,
  staleTime: Infinity,
}));
```

### Invalidation

```tsx
const queryClient = useQueryClient();

// Invalidate all todos
queryClient.invalidateQueries({ queryKey: ['todos'] });

// Invalidate specific todo
queryClient.invalidateQueries({ queryKey: ['todos', todoId] });

// Exact match only
queryClient.invalidateQueries({ queryKey: ['todos'], exact: true });
```

## When to Use Solid Query vs createResource

| Use createResource | Use Solid Query |
|--------------------|-----------------|
| Simple one-off fetches | Complex caching needs |
| No cache sharing needed | Multiple components share data |
| No background refetching | Need stale-while-revalidate |
| Simpler mental model | Need mutations with invalidation |

```tsx
// createResource - simple case
const [user] = createResource(userId, fetchUser);

// Solid Query - caching, invalidation, mutations
const query = createQuery(() => ({
  queryKey: ['user', userId()],
  queryFn: () => fetchUser(userId()),
}));
```

## DevTools

```tsx
import { SolidQueryDevtools } from '@tanstack/solid-query-devtools';

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <MyApp />
      <SolidQueryDevtools />  {/* Dev only */}
    </QueryClientProvider>
  );
}
```

## Official Docs

- [TanStack Solid Query](https://tanstack.com/query/latest/docs/framework/solid/overview)
- [Query Keys](https://tanstack.com/query/latest/docs/framework/react/guides/query-keys)
- [Mutations](https://tanstack.com/query/latest/docs/framework/react/guides/mutations)
