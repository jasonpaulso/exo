<script lang="ts">
	import { Accordion as AccordionPrimitive } from "bits-ui";
	import ChevronDownIcon from "@lucide/svelte/icons/chevron-down";
	import { cn, type WithoutChild } from "$lib/utils.js";

	let {
		ref = $bindable(null),
		class: className,
		level = 3,
		children,
		...restProps
	}: WithoutChild<AccordionPrimitive.TriggerProps> & {
		level?: AccordionPrimitive.HeaderProps["level"];
	} = $props();
</script>

<AccordionPrimitive.Header {level} class="flex">
	<AccordionPrimitive.Trigger
		data-slot="accordion-trigger"
		bind:ref
		class={cn(
			"focus-visible:border-ring focus-visible:ring-ring/50 flex flex-1 items-center justify-between gap-2 py-3 text-start text-xs font-mono tracking-[0.2em] uppercase transition-all outline-none focus-visible:ring-[3px] disabled:pointer-events-none disabled:opacity-50 [&[data-state=open]>svg]:rotate-180 text-exo-yellow hover:text-exo-yellow-glow",
			className
		)}
		{...restProps}
	>
		{@render children?.()}
		<ChevronDownIcon
			class="text-exo-yellow/60 pointer-events-none size-4 shrink-0 transition-transform duration-200"
		/>
	</AccordionPrimitive.Trigger>
</AccordionPrimitive.Header>
