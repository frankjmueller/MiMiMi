# MiMiMi - Multiplayer Word Guessing Game for Kids

A mobile-first multiplayer word-guessing game built with Phoenix LiveView for German elementary school students (Grundschüler). Players see a grid of words/images and must guess the correct word based on progressively revealed keywords (clues).

## 🎮 Game Overview

**Target Audience:** German elementary school students
**Language:** German (einfache Sprache - simple language for children)
**Platform:** Web-based, mobile-first design
**Technology:** Phoenix LiveView with real-time multiplayer features

## ✨ Features

### Game Setup (Host/Teacher)
- Configure number of rounds (1-20, default: 3)
- Set clue reveal interval (3s to 60s)
- Choose grid size (2x1, 2x2, 3x3, or 4x4)
- Generate unique 6-digit invitation code (expires after 15 minutes)
- Large, prominent display of invitation code in dashboard for easy reading
- Share code via QR code, link, or direct code entry
- 15-minute lobby timeout with countdown
- **Cancel Game**: Host can cancel the game from the waiting room before it starts, automatically redirecting all players to the home page
- Secure host authentication with cryptographic tokens
- Modern glassmorphism design with smooth animations

### Player Experience
- Join via invitation link, QR code scan, or manual 6-digit code entry
- Manual code entry form only appears when games are waiting for players (improved UX)
- Select unique animal avatar (🐻🐘🦉🐸🦊🐰🦛🐱🦁🐼)
- **Avatar Indicator**: Players see their avatar and current points in the top right corner during gameplay and game-over screen
- Real-time gameplay with progressive keyword reveals
- **Guaranteed Unique Words**: Each round features a different target word - no duplicate words across rounds in the same game
- Immediate feedback (correct/wrong)
- **Learning Feature**: After making a pick, all players see the correct answer with its image to reinforce learning
  - Players who picked correctly see "Du hast richtig getippt:" (You guessed correctly)
  - Players who picked wrong see "Richtige Antwort:" (Correct answer)
  - Responsive layout: side-by-side on desktop, stacked on mobile
- Live points tracking throughout the game
- **Smart Final Leaderboard**:
  - Players with equal points share the same rank (proper tie handling)
  - Current player's row is highlighted with purple gradient
  - Current player's avatar has white ring indicator
  - Tied players shown side-by-side on same row

### Multiplayer Features
- Real-time updates via Phoenix PubSub
- Host dashboard showing all player activity
- Automatic round progression
- Synchronized game state across all devices
- Active games counter in footer
- **Host Disconnect Handling**: When the game host closes their browser, all players are automatically redirected to the home page with an informative flash message
- **Quick Rematch/Restart**: After game completion, the host can instantly start a new game with the same players by clicking "Neues Spiel mit denselben Spielern" button on the game-over screen
  - Game automatically starts and jumps straight to round 1 with countdown running
  - All online players are automatically redirected to the new game and see a loading state while rounds are being generated
  - Once rounds are ready, players automatically see round 1 gameplay screen
  - Host is redirected to their dashboard view showing the active game
  - Players keep their original avatars in the rematch
  - Host sees status of online/offline players before starting

### Content Guarantees
- **Images by construction**: the `mimimi.words` delivery view only serves words that have an image, so the round pool needs no per-word image check (ADR 0075)
- **Keyword Validation**: keyword ids are resolved against the keywords view before use in rounds
- **Graceful Error Handling**: games fail early with informative German error messages if insufficient content is available
- This prevents players from seeing broken images or "???" placeholder keywords during gameplay

### Word List Page
- Browse words from the ourwords delivery views that have keywords and images
- Visit `/list_words` to see the collection with visuals (staff-gated in production — see M4)
- Each word displays its image and all associated keywords
- Filter words by minimum number of keywords using the interactive slider
- Slider range dynamically adjusts to the maximum keyword count available
- Images use the relative delivery path prefixed with `OURWORDS_ASSET_BASE_URL`

### Debug Page
- System diagnostics at `/debug` (excluded from search engines via robots.txt)
- Displays Elixir version, Phoenix version, app version, and build timestamp
- Shows WortSchule database connection status
- Reports table counts for all WortSchule tables:
  - Total words, words with images, words with keywords
  - Words with both keywords and images (usable in game)
  - Keywords, ActiveStorage attachments and blobs
- Error handling with detailed error messages for troubleshooting
- **Round Generation Debug Info**: If players see the "Runden werden vorbereitet..." (Preparing rounds) screen for more than a few seconds, debug information is displayed showing:
  - Game ID, Game State, Player ID
  - Timestamp when waiting started
  - Automatic timeout check after 10 seconds to recover from missed broadcasts
  - Fallback mechanism to load rounds directly from database if broadcast fails

## 🎨 Design System

The application uses a modern **glassmorphism design language** with:
- Frosted glass card effects with backdrop blur
- Soft gradient backgrounds (indigo → white)
- Smooth transitions and micro-interactions
- Context-specific gradient icon badges
- Color-matched shadows on interactive elements
- Full dark mode support

See `CLAUDE.md` for complete design system documentation.

## 🏗️ Implementation Status

### ✅ Completed

1. **Database Layer** - All 7 tables migrated with proper indexes and foreign keys
2. **Ecto Schemas** - User, Game, Player, Word, Keyword, Round, Pick
3. **Context Layer** - Complete Games context with all CRUD operations and PubSub
4. **WortSchule Integration** - Full integration with wort.schule database for German word data
5. **Session Management** - Auto-create users based on session (no login required)
6. **Security** - Host authentication with cryptographic tokens (prevents waiting room hijacking)
7. **UI/UX Design** - Glassmorphism design system applied across all LiveViews
8. **LiveView Components** - Complete gameplay, dashboard, avatar selection, and lobby views
9. **Real-time Multiplayer** - Full game flow with progressive keyword reveals and synchronized state
10. **Comprehensive Testing** - Integration tests covering complete 2-3 player game scenarios

### ✅ Game is Fully Functional

The game is now complete and working correctly! Comprehensive integration tests verify:
- Two players completing a full 2-round game
- Three players with different pick speeds
- Mixed correct/wrong answers
- Points accumulation across rounds
- Proper game state transitions
- Leaderboard calculation

## 🚀 Getting Started

```bash
# Install dependencies
mix deps.get

# Create and migrate database
mix ecto.setup

# Start Phoenix server
mix phx.server
```

Visit `http://localhost:4000`

## 📊 Scoring System

Points are awarded based on how many keywords a player needed to see before guessing correctly:

- Guess with 1 keyword shown: **5 points**
- Guess with 2 keywords shown: **3 points**
- Guess with 3 keywords shown: **1 point**
- Wrong answer: **0 points**

The faster you guess (fewer keywords needed), the more points you earn!

## 🔒 Security

### Host Authentication
- Each game generates a unique cryptographic host token (32-byte secure random)
- Host token stored in signed session cookie (expires after 24 hours)
- Waiting room access requires valid host token matching the game's stored token
- Prevents unauthorized users from hijacking the waiting room and starting games
- Even with the same URL, attackers cannot impersonate the game host without the valid token

## 🔗 ourwords Integration (delivery schema, ADR 0075)

This application reads word, keyword and image data from **ourwords** through a dedicated Postgres
schema `mimimi` — three read-only views (`mimimi.words`, `mimimi.keywords`, `mimimi.playable_languages`)
plus one analytics table it writes to (`mimimi.keyword_effectiveness`). This replaces the older direct
read of the flat wort.schule `words` table with its self-referential keyword join and its per-word image
HTTP call. Key differences:

- **Keyword ids are `sense_relation` ids** — a namespace of their own, never word ids. Resolve them with
  `Mimimi.WortSchule.get_keywords_batch/1`, never via the words view.
- **`image_url` is a relative path** carried by the view; the game prepends `OURWORDS_ASSET_BASE_URL`.
  There is no image URL cache and no per-word image validation anymore — the view only serves words that
  have an image.
- The delivery views are **published-only by construction** (defined over the ourwords read-model), so a
  draft can never reach the game.

### Configuration

The read-only repository `Mimimi.WortSchuleRepo` points at the ourwords database via a dedicated
SELECT-only role:

- `OURWORDS_DATABASE_URL` — the connection URL (with the `mimimi_game` role). For one release generation
  the old `WORTSCHULE_DATABASE_URL` is still accepted as a fallback.
- `OURWORDS_ASSET_BASE_URL` — the base URL prepended to the view's relative image paths (empty → paths
  pass through unchanged).

In test, `Mimimi.WortSchuleRepo` points at `mimimi_words_test`, a local fixture rebuild of the delivery
schema (`test/support/fixtures/ourwords_mimimi_schema.sql`) — no external database, no network.

### Usage

```elixir
# A complete word: keywords keyed by sense_relation id, absolute image url
{:ok, word} = Mimimi.WortSchule.get_complete_word(123)
# => %{id: 123, name: "Affe", keywords: [%{id: 456, name: "Tier"}], image_url: "https://…/rails/…"}

# Resolve round keyword ids (sense_relation ids) to labels
Mimimi.WortSchule.get_keywords_batch([456, 789])

# Playable-word ids for a language, filtered by image + keyword count + type
Mimimi.WortSchule.get_word_ids_with_keywords_and_images(min_keywords: 3, types: ["Noun"], language: "deu")
```

### Image URLs

`mimimi.words.image_url` is a **relative** ActiveStorage path (e.g. `/rails/active_storage/...`). The game
prepends `OURWORDS_ASSET_BASE_URL` to it in `get_complete_word/1`; with an empty base the path passes
through unchanged. There is no image URL cache and no per-word HTTP call anymore.

## 📄 Deployment

See [DEPLOYMENT.md](DEPLOYMENT.md) for production deployment with hot code upgrades.

### Troubleshooting Static Files

If static files (like the BMBFSFJ logo in the footer) aren't displaying on production:

1. **Run the diagnostic script on the server:**
   ```bash
   ./scripts/debug_static_files.sh
   ```

2. **Common issues and fixes:**
   - **Broken symlink**: The script will automatically fix the `/var/www/mimimi/shared/static` symlink
   - **Missing files**: Redeploy with `git push` to trigger GitHub Actions
   - **Permission issues**: Check nginx user and file permissions
   - **Nginx config**: Verify static file location matches `/var/www/mimimi/shared/static`

3. **Check nginx error logs:**
   ```bash
   sudo tail -100 /var/log/nginx/error.log
   ```

4. **Restart nginx after fixes:**
   ```bash
   sudo systemctl restart nginx
   ```

## Logging

View Real-time Logs on production

### Watch logs as they happen
sudo journalctl -u mimimi -f

### Or last 200 lines
sudo journalctl -u mimimi -n 200
