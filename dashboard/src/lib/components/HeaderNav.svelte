<script lang="ts">
  import { browser } from "$app/environment";
  import { mode, setMode, resetMode } from "mode-watcher";
  import * as DropdownMenu from "$lib/components/ui/dropdown-menu";

  export let showHome = true;
  export let onHome: (() => void) | null = null;
  export let showSidebarToggle = false;
  export let sidebarVisible = true;
  export let onToggleSidebar: (() => void) | null = null;

  function handleHome(): void {
    if (onHome) {
      onHome();
      return;
    }
    if (browser) {
      // Hash router: send to root
      window.location.hash = "/";
    }
  }

  function handleToggleSidebar(): void {
    if (onToggleSidebar) {
      onToggleSidebar();
    }
  }
</script>

<header
  class="relative z-20 flex items-center justify-center px-6 pt-8 pb-4 bg-exo-dark-gray"
>
  <!-- Left: Sidebar Toggle -->
  {#if showSidebarToggle}
    <div class="absolute left-6 top-1/2 -translate-y-1/2">
      <button
        onclick={handleToggleSidebar}
        class="p-2 rounded border border-exo-medium-gray/40 hover:border-exo-yellow/50 transition-colors cursor-pointer"
        title={sidebarVisible ? "Hide sidebar" : "Show sidebar"}
      >
        <svg
          class="w-5 h-5 {sidebarVisible
            ? 'text-exo-yellow'
            : 'text-exo-medium-gray'}"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          stroke-width="2"
        >
          {#if sidebarVisible}
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M11 19l-7-7 7-7m8 14l-7-7 7-7"
            />
          {:else}
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M13 5l7 7-7 7M5 5l7 7-7 7"
            />
          {/if}
        </svg>
      </button>
    </div>
  {/if}

  <!-- Center: Logo (clickable to go home) -->
  <button
    onclick={handleHome}
    class="bg-transparent border-none outline-none focus:outline-none transition-opacity duration-200 hover:opacity-90 {showHome
      ? 'cursor-pointer'
      : 'cursor-default'}"
    title={showHome ? "Go to home" : ""}
    disabled={!showHome}
  >
    <img
      src="/exo-logo.png"
      alt="EXO"
      class="h-18 drop-shadow-[0_0_20px_rgba(255,215,0,0.5)]"
    />
  </button>

  <!-- Right: Theme Toggle + Home + Downloads -->
  <div
    class="absolute right-6 top-1/2 -translate-y-1/2 flex items-center gap-4"
  >
    <!-- Theme Toggle -->
    <DropdownMenu.Root>
      <DropdownMenu.Trigger
        class="p-2 rounded border border-exo-medium-gray/40 hover:border-exo-yellow/50 transition-colors cursor-pointer"
        title="Toggle theme"
      >
        {#if mode.current === "light"}
          <svg
            class="w-4 h-4 text-exo-yellow"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="2"
          >
            <circle cx="12" cy="12" r="5" />
            <line x1="12" y1="1" x2="12" y2="3" />
            <line x1="12" y1="21" x2="12" y2="23" />
            <line x1="4.22" y1="4.22" x2="5.64" y2="5.64" />
            <line x1="18.36" y1="18.36" x2="19.78" y2="19.78" />
            <line x1="1" y1="12" x2="3" y2="12" />
            <line x1="21" y1="12" x2="23" y2="12" />
            <line x1="4.22" y1="19.78" x2="5.64" y2="18.36" />
            <line x1="18.36" y1="5.64" x2="19.78" y2="4.22" />
          </svg>
        {:else}
          <svg
            class="w-4 h-4 text-exo-yellow"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="2"
          >
            <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" />
          </svg>
        {/if}
      </DropdownMenu.Trigger>
      <DropdownMenu.Content align="end" class="min-w-32">
        <DropdownMenu.Item onclick={() => setMode("light")} class="gap-2 cursor-pointer">
          <svg
            class="w-4 h-4"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="2"
          >
            <circle cx="12" cy="12" r="5" />
            <line x1="12" y1="1" x2="12" y2="3" />
            <line x1="12" y1="21" x2="12" y2="23" />
            <line x1="4.22" y1="4.22" x2="5.64" y2="5.64" />
            <line x1="18.36" y1="18.36" x2="19.78" y2="19.78" />
            <line x1="1" y1="12" x2="3" y2="12" />
            <line x1="21" y1="12" x2="23" y2="12" />
            <line x1="4.22" y1="19.78" x2="5.64" y2="18.36" />
            <line x1="18.36" y1="5.64" x2="19.78" y2="4.22" />
          </svg>
          Light
        </DropdownMenu.Item>
        <DropdownMenu.Item onclick={() => setMode("dark")} class="gap-2 cursor-pointer">
          <svg
            class="w-4 h-4"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="2"
          >
            <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" />
          </svg>
          Dark
        </DropdownMenu.Item>
        <DropdownMenu.Item onclick={() => resetMode()} class="gap-2 cursor-pointer">
          <svg
            class="w-4 h-4"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="2"
          >
            <rect x="2" y="3" width="20" height="14" rx="2" ry="2" />
            <line x1="8" y1="21" x2="16" y2="21" />
            <line x1="12" y1="17" x2="12" y2="21" />
          </svg>
          System
        </DropdownMenu.Item>
      </DropdownMenu.Content>
    </DropdownMenu.Root>

    {#if showHome}
      <button
        onclick={handleHome}
        class="text-sm text-exo-light-gray hover:text-exo-yellow transition-colors tracking-wider uppercase flex items-center gap-2 cursor-pointer"
        title="Back to topology view"
      >
        <svg
          class="w-4 h-4"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"
          />
        </svg>
        Home
      </button>
    {/if}
    <a
      href="/#/downloads"
      class="text-sm text-exo-light-gray hover:text-exo-yellow transition-colors tracking-wider uppercase flex items-center gap-2 cursor-pointer"
      title="View downloads overview"
    >
      <svg
        class="w-4 h-4"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <path d="M12 3v12" />
        <path d="M7 12l5 5 5-5" />
        <path d="M5 21h14" />
      </svg>
      Downloads
    </a>
  </div>
</header>
