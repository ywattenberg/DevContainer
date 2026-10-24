import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth } from "@earendil-works/pi-tui";

const reset = "\x1b[0m";
const fg = (hex: string) => `\x1b[38;2;${hexToRgb(hex)}m`;
const bg = (hex: string) => `\x1b[48;2;${hexToRgb(hex)}m`;

const crust = "#11111b";
const mauve = "#cba6f7";
const blue = "#89b4fa";
const teal = "#94e2d5";

function hexToRgb(hex: string): string {
    const value = hex.replace(/^#/, "");
    const r = Number.parseInt(value.slice(0, 2), 16);
    const g = Number.parseInt(value.slice(2, 4), 16);
    const b = Number.parseInt(value.slice(4, 6), 16);
    return `${r};${g};${b}`;
}

function segment(text: string, foreground: string, background: string): string {
    return `${fg(foreground)}${bg(background)}${text}${reset}`;
}

function transition(from: string, to: string): string {
    return `${fg(from)}${bg(to)}${reset}`;
}

function formatTokens(tokens?: number): string {
    if (!tokens || !Number.isFinite(tokens)) return "?";
    if (tokens >= 1_000_000) return `${(tokens / 1_000_000).toFixed(1)}M`;
    return `${Math.round(tokens / 1000)}k`;
}

function formatContext(ctx: any): string {
    const usage = ctx.getContextUsage?.();
    const contextWindow = usage?.contextWindow ?? ctx.model?.contextWindow;
    const percent = usage?.percent;
    if (typeof percent === "number" && contextWindow) {
        return `ctx ${Math.round(percent)}%/${formatTokens(contextWindow)}`;
    }
    return `ctx ${formatTokens(contextWindow)}`;
}

function buildStatus(ctx: any, pi: ExtensionAPI): string {
    const provider = ctx.model?.provider ?? "pi";
    const model = ctx.model?.id ?? "no-model";
    const thinking = pi.getThinkingLevel?.() ?? "context";
    const context = formatContext(ctx);

    return [
        `${fg(mauve)}${reset}`,
        segment(` 󰚩 ${provider} `, crust, mauve),
        transition(mauve, blue),
        segment(`  ${model} `, crust, blue),
        transition(blue, teal),
        segment(` 󰊠 ${thinking} · ${context} `, crust, teal),
        `${fg(teal)}${reset}`,
    ].join("");
}

export default function (pi: ExtensionAPI) {
    let requestRender: (() => void) | undefined;

    pi.on("session_start", async (_event, ctx) => {
        ctx.ui.setFooter((tui) => {
            const rerender = () => tui.requestRender();
            requestRender = rerender;

            return {
                render(width: number): string[] {
                    return [truncateToWidth(buildStatus(ctx, pi), width)];
                },
                invalidate() {},
                dispose() {
                    if (requestRender === rerender) requestRender = undefined;
                },
            };
        });
    });

    const update = () => requestRender?.();
    pi.on("model_select", async () => update());
    pi.on("thinking_level_select", async () => update());
    pi.on("turn_start", async () => update());
    pi.on("turn_end", async () => update());
}
