# Video naming page — requirements for d2m

Screen slug `video-naming`, display name "Video naming", derived from `edit-text-single-field`.
Source of truth: `docs/features/video-naming/SPEC.md` (decisions D1, D3, D5, D11, D12, D16, D18).
iPhone only. The page is shown after a leader saves a recorded or imported video from the + menu.

## Layout (top to bottom)

1. Header titled **"Name your video"**: a back control on the left and the purple C-159 check on
   the right (the same header as `edit-text-single-field`). Back leaves without saving; the check saves.
2. **Title** field: the single-line field `edit-text-single-field` uses (C-045 / C-046). Starts
   empty. A placeholder is supplied by the caller (it reads "Video 3" and so on, never fixed copy).
   Capped at 80 characters.
3. **Description** field: multi-line, as in `edit-text-multi-field`. Starts empty. Capped at 300.
4. **AI Suggestions** block: C-051 below the fields.

The page scrolls, and the focused field stays above the keyboard (keyboard-safe scrolling).

## The suggestions block (C-051 with C-078 rows)

Each suggestion is a pair: a title and a description. Show at most three rows. A row shows its
title on the first line and its description below it (two lines per row). Tapping a row answers
the row's index; the caller then replaces both fields with that pair. The block stays in `list`
afterwards.

States, and the block is visible in every one of them (never hidden):

| State | Shows |
|---|---|
| `generating` | C-051's loading body (the existing "Processing" row) |
| `list` | the header and up to three pair rows, with the regenerate link |
| `regenerating` | the status row over the same rows, still pickable |
| `prompt` | copy "Couldn't get suggestions" and the link "AI suggestions" (asks again) |
| `empty` (new) | copy "No speech to suggest from", **no link** |

`empty` is a new fifth raw value on `AISuggestionsBlock.State`, raw string `"empty"`.

## Additive change to C-051 and C-078 (build-time risk)

Today C-051 takes string rows, has no empty state, draws its own rows and picks by title. Make
only additive changes, so every existing caller renders exactly as before:

- pair rows: a second suggestions input of title and description pairs; the string input stays.
- pick by index: a new index callback beside the existing title callback.
- the `empty` state.

The shared-edit-field screens (`edit-text-single-field`, `edit-text-multi-field`) must not change:
no existing capture of theirs may differ after the build.

## Inputs the screen takes

`title`, `titlePlaceholder`, `description` (strings); `aiState` (`AISuggestionsBlock.State`);
`promptCopy` (string); `suggestions` (title and description pairs); `onTitleChange` and
`onDescriptionChange` (string); `onPick` (index); `onRegenerate`; `onSave`; `onBack`.

## Captures

Captures are silent: nothing plays sound. Seed the text; never run the transcriber. Capture the
states `generating`, `list` (three pairs, long title and description to show wrapping),
`regenerating`, `prompt`, `empty`, and one with both fields filled.

The owner approves the captures before any wiring.

## As built

(d2m and the implementer fill this in after the build: the actual input names where they differ.)
