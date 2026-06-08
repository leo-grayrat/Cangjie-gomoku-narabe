'use strict';

(function () {
  const MUSIC_ENABLED_KEY = 'gomokuMusicEnabled';
  const DISCIPLINE_LOCK_KEY = 'gomokuModeLock';
  const DISCIPLINE_PENDING_KEY = 'gomokuDisciplinePending';
  const DISCIPLINE_LOCK_VALUE = 'easy-only';
  const FADE_MS = 1500;
  const MUSIC_VOLUME_KEY = 'gomokuMusicVolume';
  const MAX_VOLUME = 0.30;

  function initialEnabled() {
    const saved = localStorage.getItem(MUSIC_ENABLED_KEY);
    return saved === null ? true : saved === '1';
  }

  function initialVolumePercent() {
    const raw = localStorage.getItem(MUSIC_VOLUME_KEY);
    if (raw === null) return 100;

    const saved = Number(raw);
    if (Number.isFinite(saved)) {
      return Math.max(0, Math.min(100, saved));
    }
    return 100;
  }

  const musicState = {
    tracks: new Map(),
    enabled: initialEnabled(),
    volumePercent: initialVolumePercent(),
    currentAudio: null,
    currentKey: '',
    targetKey: 'main',
    forcedKey: '',
    transitionId: 0,
    retryHandler: null,
    context: {
      view: 'home',
      mode: 'pvp',
      difficulty: 'easy'
    }
  };

  function nodes() {
    return {
      panel: document.getElementById('music-panel'),
      toggle: document.getElementById('music-toggle'),
      label: document.getElementById('music-label'),
      title: document.getElementById('music-title'),
      artist: document.getElementById('music-artist'),
      volume: document.getElementById('music-volume'),
      netease: document.getElementById('music-netease'),
      qq: document.getElementById('music-qq')
    };
  }

  function lockedToSp() {
    return !!localStorage.getItem(DISCIPLINE_PENDING_KEY)
      || localStorage.getItem(DISCIPLINE_LOCK_KEY) === DISCIPLINE_LOCK_VALUE;
  }

  function targetMusicForView() {
    if (musicState.forcedKey) return musicState.forcedKey;
    if (lockedToSp()) return 'sp';
    if (musicState.context.view === 'home') return 'main';
    if (musicState.context.mode === 'pvp') return 'offline';
    if (musicState.context.mode === 'lan') return 'online';
    if (musicState.context.mode === 'ai') return musicState.context.difficulty || 'easy';
    return 'main';
  }

  function trackFor(key) {
    return musicState.tracks.get(key) || musicState.tracks.get('main') || null;
  }

  function targetVolume() {
    return MAX_VOLUME * (musicState.volumePercent / 100);
  }

  function setAudioVolume(audio, volume) {
    if (!audio) return;
    audio.volume = Math.max(0, Math.min(targetVolume(), volume));
  }

  function stopAudio(audio) {
    if (!audio) return;
    audio.pause();
    audio.currentTime = 0;
    audio.src = '';
  }

  function cancelRetry() {
    if (!musicState.retryHandler) return;
    window.removeEventListener('pointerdown', musicState.retryHandler);
    window.removeEventListener('keydown', musicState.retryHandler);
    musicState.retryHandler = null;
  }

  function armRetry() {
    if (musicState.retryHandler || !musicState.enabled) return;
    musicState.retryHandler = () => {
      cancelRetry();
      if (musicState.enabled) {
        requestMusic(musicState.targetKey);
      }
    };
    window.addEventListener('pointerdown', musicState.retryHandler);
    window.addEventListener('keydown', musicState.retryHandler);
  }

  function updatePanel(key) {
    const el = nodes();
    const track = trackFor(key);
    if (!el.panel) return;

    el.panel.classList.toggle('music-on', musicState.enabled);
    if (el.volume) {
      el.volume.value = `${musicState.volumePercent}`;
    }
    el.toggle.textContent = musicState.enabled ? '音乐 开' : '音乐 关';

    if (!track) {
      el.label.textContent = key || 'Main';
      el.title.textContent = '等待曲目';
      el.artist.textContent = '--';
      el.netease.href = '#';
      el.qq.href = '#';
      el.netease.classList.add('disabled');
      el.qq.classList.add('disabled');
      return;
    }

    el.label.textContent = track.sourceLabel || key.toUpperCase();
    el.title.textContent = track.title || '未选择曲目';
    el.artist.textContent = track.artist || '';
    el.netease.href = track.neteaseUrl || '#';
    el.qq.href = track.qqMusicUrl || '#';
    el.netease.classList.toggle('disabled', !track.neteaseUrl);
    el.qq.classList.toggle('disabled', !track.qqMusicUrl);
  }

  function fadeOutAndStop(audio, transitionId, duration = FADE_MS) {
    if (!audio) return;
    const startVolume = audio.volume;
    const startedAt = performance.now();

    function step(now) {
      if (transitionId !== musicState.transitionId) {
        stopAudio(audio);
        return;
      }
      const t = Math.min(1, (now - startedAt) / duration);
      setAudioVolume(audio, startVolume * (1 - t));
      if (t < 1) {
        requestAnimationFrame(step);
      } else {
        stopAudio(audio);
      }
    }

    requestAnimationFrame(step);
  }

  function fadeIn(audio, transitionId) {
    const startedAt = performance.now();

    function step(now) {
      if (transitionId !== musicState.transitionId) {
        stopAudio(audio);
        return;
      }
      const t = Math.min(1, (now - startedAt) / FADE_MS);
      setAudioVolume(audio, targetVolume() * t);
      if (t < 1) {
        requestAnimationFrame(step);
      }
    }

    requestAnimationFrame(step);
  }

  function stopCurrent() {
    cancelRetry();
    const transitionId = ++musicState.transitionId;
    const oldAudio = musicState.currentAudio;
    musicState.currentAudio = null;
    musicState.currentKey = '';
    fadeOutAndStop(oldAudio, transitionId);
  }

  function setEnabled(enabled) {
    musicState.enabled = enabled;
    localStorage.setItem(MUSIC_ENABLED_KEY, enabled ? '1' : '0');
    updatePanel(musicState.targetKey);

    if (enabled) {
      requestMusic(musicState.targetKey);
    } else {
      stopCurrent();
    }
  }

  function setVolumePercent(value) {
    const parsed = Number(value);
    const next = Number.isFinite(parsed) ? Math.max(0, Math.min(100, parsed)) : 100;
    musicState.volumePercent = next;
    localStorage.setItem(MUSIC_VOLUME_KEY, `${next}`);
    if (musicState.currentAudio) {
      setAudioVolume(musicState.currentAudio, targetVolume());
    }
    updatePanel(musicState.targetKey);
  }

  async function requestMusic(key) {
    const nextKey = key || 'main';
    musicState.targetKey = nextKey;
    updatePanel(nextKey);

    if (!musicState.enabled) {
      return;
    }

    if (musicState.currentKey === nextKey && musicState.currentAudio) {
      return;
    }

    const track = trackFor(nextKey);
    if (!track) {
      return;
    }

    cancelRetry();

    const transitionId = ++musicState.transitionId;
    const oldAudio = musicState.currentAudio;
    const oldKey = musicState.currentKey;
    const incoming = new Audio(track.route);
    incoming.loop = true;
    incoming.preload = 'auto';
    incoming.volume = 0;

    try {
      await incoming.play();
    } catch (_error) {
      if (transitionId === musicState.transitionId) {
        musicState.currentAudio = oldAudio;
        musicState.currentKey = oldKey;
        updatePanel(oldKey || nextKey);
      }
      stopAudio(incoming);
      if (musicState.enabled && !oldAudio) {
        armRetry();
      }
      return;
    }

    if (transitionId !== musicState.transitionId) {
      stopAudio(incoming);
      return;
    }

    musicState.currentAudio = incoming;
    musicState.currentKey = nextKey;
    updatePanel(nextKey);
    fadeOutAndStop(oldAudio, transitionId);
    fadeIn(incoming, transitionId);
  }

  function syncMusic(context) {
    if (context) {
      musicState.context = {
        view: context.view || musicState.context.view,
        mode: context.mode || musicState.context.mode,
        difficulty: context.difficulty || musicState.context.difficulty
      };
    }
    requestMusic(targetMusicForView());
  }

  function forceTrack(key) {
    musicState.forcedKey = key || '';
    syncMusic();
  }

  function clearForcedTrack() {
    musicState.forcedKey = '';
    syncMusic();
  }

  async function loadManifest() {
    try {
      const response = await fetch('/api/music');
      const data = await response.json();
      (data.tracks || []).forEach((track) => {
        musicState.tracks.set(track.key, track);
      });
    } catch (_error) {
      // Keep the panel usable even if metadata failed to load.
    }
    syncMusic();
  }

  function bindUI() {
    const el = nodes();
    if (!el.toggle) return;
    el.toggle.addEventListener('click', () => {
      setEnabled(!musicState.enabled);
    });
    if (el.volume) {
      el.volume.value = `${musicState.volumePercent}`;
      el.volume.addEventListener('input', (event) => {
        setVolumePercent(event.target.value);
      });
    }
    updatePanel('main');
  }

  window.gomokuMusic = {
    syncMusic,
    forceTrack,
    clearForcedTrack,
    setEnabled,
    setVolumePercent
  };

  bindUI();
  loadManifest();
})();
