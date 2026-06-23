import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import CssBaseline from '@mui/material/CssBaseline';
import { ThemeProvider, createTheme } from '@mui/material/styles';
import App from './App';
import { ToastProvider } from './ui/Toast';
import { ConfirmProvider } from './ui/ConfirmDialog';

// --- Restricted banking palette --------------------------------------------
// Only four hue families are allowed across the UI:
//   · white background
//   · blue (brand, actions, neutral/positive states) — several tones
//   · yellow (warnings / alerts)
//   · red (errors / destructive)
// Greys are reserved for text, hairline borders and inert states.
const NAVY = '#15539e';        // primary blue (actions, links)
const NAVY_DARK = '#0d2740';   // deep blue (app bar, headers)
const NAVY_LIGHT = '#4f83c2';  // light blue
const INK = '#16202c';
const INK_SOFT = '#5a6b7b';
const CANVAS = '#ffffff';      // white background
const BORDER = '#dbe4f0';      // blue-tinted hairline
const BORDER_SOFT = '#e9eff7';

const SANS = '"Plus Jakarta Sans", system-ui, -apple-system, "Segoe UI", Roboto, sans-serif';
const MONO = '"JetBrains Mono", ui-monospace, "SFMono-Regular", Menlo, monospace';

const theme = createTheme({
  palette: {
    mode: 'light',
    primary: { main: NAVY, dark: NAVY_DARK, light: NAVY_LIGHT, contrastText: '#ffffff' },
    secondary: { main: '#1976d2' },
    // No green in the palette: positive/success states are rendered in blue.
    success: { main: '#1565c0', contrastText: '#ffffff' },
    error: { main: '#d32f2f', contrastText: '#ffffff' },
    warning: { main: '#e6a700', contrastText: '#3a2c00' },
    info: { main: '#1976d2', contrastText: '#ffffff' },
    background: { default: CANVAS, paper: '#ffffff' },
    text: { primary: INK, secondary: INK_SOFT },
    divider: BORDER,
  },
  shape: { borderRadius: 12 },
  typography: {
    fontFamily: SANS,
    h4: { fontWeight: 800, letterSpacing: '-0.02em', fontSize: '1.6rem' },
    h5: { fontWeight: 700, letterSpacing: '-0.015em' },
    h6: { fontWeight: 700, letterSpacing: '-0.01em', fontSize: '1.05rem' },
    subtitle2: { fontWeight: 600 },
    overline: { fontWeight: 700, letterSpacing: '0.12em' },
    button: { fontWeight: 600 },
  },
  components: {
    MuiCssBaseline: {
      styleOverrides: {
        body: {
          fontFeatureSettings: '"tnum" 1, "cv05" 1',
          WebkitFontSmoothing: 'antialiased',
        },
        ':root': { colorScheme: 'light' },
        '::selection': { backgroundColor: 'rgba(21,83,158,0.16)' },
        '*::-webkit-scrollbar': { width: 11, height: 11 },
        '*::-webkit-scrollbar-thumb': {
          backgroundColor: '#c4cedb',
          borderRadius: 8,
          border: '3px solid transparent',
          backgroundClip: 'content-box',
        },
        '*::-webkit-scrollbar-thumb:hover': { backgroundColor: '#a9b6c7' },
        '*::-webkit-scrollbar-track': { background: 'transparent' },
      },
    },
    MuiAppBar: {
      styleOverrides: { root: { backgroundImage: 'none' } },
    },
    MuiButton: {
      defaultProps: { disableElevation: true },
      styleOverrides: {
        root: {
          textTransform: 'none',
          borderRadius: 9,
          paddingInline: 16,
          transition: 'background-color .2s ease, box-shadow .2s ease, transform .08s ease',
          '&:active': { transform: 'translateY(1px)' },
        },
        containedPrimary: {
          boxShadow: '0 1px 2px rgba(13,39,64,0.25)',
          '&:hover': { boxShadow: '0 4px 12px rgba(13,39,64,0.22)' },
        },
        outlined: { borderColor: BORDER },
      },
    },
    MuiIconButton: {
      styleOverrides: {
        root: { transition: 'background-color .18s ease, color .18s ease' },
      },
    },
    MuiCard: {
      defaultProps: { elevation: 0 },
      styleOverrides: {
        root: {
          border: `1px solid ${BORDER}`,
          borderRadius: 16,
          boxShadow: '0 1px 2px rgba(13,39,64,0.05)',
        },
      },
    },
    MuiPaper: {
      styleOverrides: { outlined: { borderColor: BORDER } },
    },
    MuiTableContainer: {
      styleOverrides: { root: { borderRadius: 16 } },
    },
    MuiTableCell: {
      styleOverrides: {
        head: {
          backgroundColor: '#eef4fc',
          color: '#3f5d86',
          fontWeight: 700,
          fontSize: 11,
          letterSpacing: '0.07em',
          textTransform: 'uppercase',
          borderColor: BORDER,
          whiteSpace: 'nowrap',
        },
        root: { borderColor: BORDER_SOFT, fontVariantNumeric: 'tabular-nums' },
      },
    },
    MuiTableRow: {
      styleOverrides: {
        root: {
          '&:last-child td': { borderBottom: 0 },
          '&.MuiTableRow-hover:hover': { backgroundColor: 'rgba(21,83,158,0.05)' },
        },
      },
    },
    MuiChip: {
      styleOverrides: {
        root: { fontWeight: 600, borderRadius: 8 },
        outlined: { borderColor: BORDER },
      },
    },
    MuiDrawer: {
      styleOverrides: {
        paper: { borderRight: `1px solid ${BORDER}`, backgroundColor: '#ffffff' },
      },
    },
    MuiDialog: {
      styleOverrides: {
        paper: {
          borderRadius: 18,
          border: `1px solid ${BORDER}`,
          boxShadow: '0 24px 60px -12px rgba(13,39,64,0.32)',
        },
      },
    },
    MuiDialogTitle: {
      styleOverrides: { root: { fontWeight: 700, letterSpacing: '-0.01em' } },
    },
    MuiBackdrop: {
      styleOverrides: {
        root: { backgroundColor: 'rgba(13,39,64,0.42)', backdropFilter: 'blur(2px)' },
      },
    },
    MuiOutlinedInput: {
      styleOverrides: {
        root: {
          borderRadius: 10,
          '& .MuiOutlinedInput-notchedOutline': { borderColor: BORDER },
          '&:hover .MuiOutlinedInput-notchedOutline': { borderColor: '#c4cedb' },
        },
      },
    },
    MuiTab: {
      styleOverrides: { root: { textTransform: 'none', fontWeight: 600, minHeight: 44 } },
    },
    MuiTooltip: {
      styleOverrides: {
        tooltip: {
          backgroundColor: NAVY_DARK,
          fontSize: 12,
          fontWeight: 500,
          borderRadius: 8,
          paddingInline: 10,
        },
        arrow: { color: NAVY_DARK },
      },
    },
  },
});

// Expose the data/monospace family for figures and identifiers (IBAN, ids).
declare module '@mui/material/styles' {
  interface Theme {
    monoFont: string;
  }
  interface ThemeOptions {
    monoFont?: string;
  }
}
theme.monoFont = MONO;

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <ToastProvider>
        <ConfirmProvider>
          <BrowserRouter>
            <App />
          </BrowserRouter>
        </ConfirmProvider>
      </ToastProvider>
    </ThemeProvider>
  </React.StrictMode>,
);
