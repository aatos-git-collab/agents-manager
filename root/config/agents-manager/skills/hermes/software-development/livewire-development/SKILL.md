---
name: livewire-development
description: livewire-development skill
  Develops reactive Livewire 3 components. Activates when creating, updating, or modifying
  Livewire components; working with wire:model, wire:click, wire:loading, or any wire: directives;
  adding real-time updates, loading states, or reactivity; debugging component behavior;
  writing Livewire tests.
---

# Livewire Development

## When to Apply

Activate this skill when:
- Creating new Livewire components
- Modifying existing component state or behavior
- Debugging reactivity or lifecycle issues
- Writing Livewire component tests
- Adding Alpine.js interactivity to components
- Working with wire: directives

## Livewire 3 Key Changes

- Use `wire:model.live` for real-time updates (not `wire:model` which is deferred)
- Components use `App\Livewire` namespace (not `App\Http\Livewire`)
- Use `$this->dispatch()` to dispatch events (not `emit` or `dispatchBrowserEvent`)
- Use `components.layouts.app` as layout path (not `layouts.app`)

## New Directives

- `wire:show`, `wire:transition`, `wire:cloak`, `wire:offline`, `wire:target`

## Best Practices

### Lifecycle Hooks

```php
public function mount(User $user) { $this->user = $user; }
public function updatedSearch() { $this->resetPage(); }
```

### Keys in Loops

```blade
@foreach ($items as $item)
    <div wire:key="item-{{ $item->id }}">
        {{ $item->name }}
    </div>
@endforeach
```

## JavaScript Hooks

```js
document.addEventListener('livewire:init', function () {
    Livewire.hook('request', ({ fail }) => {
        if (fail && fail.status === 419) {
            alert('Your session expired');
        }
    });
});
```

## Testing

Use `php artisan make:livewire Test\ComponentTest`
## Quick Commands
- `skill-load livewire-development` — Load this skill
