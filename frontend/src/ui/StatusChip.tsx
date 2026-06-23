import Chip from '@mui/material/Chip';
import Box from '@mui/material/Box';

type Color = 'success' | 'default' | 'error' | 'warning' | 'info' | 'primary';

// Restricted palette: blue for positive/neutral-active, yellow for pending or
// attention, red for terminal/error, grey for inert. No green.
const COLORS: Record<string, Color> = {
  ACTIVE: 'info', // blue
  APPROVED: 'primary', // blue
  REQUESTED: 'warning', // yellow (pending)
  INACTIVE: 'warning', // yellow
  BLOCKED: 'warning', // yellow
  DELETED: 'error', // red
  CANCELLED: 'error', // red
  REJECTED: 'error', // red
  DEFAULTED: 'error', // red
  CLOSED: 'default', // grey (inert)
  PAID: 'default', // grey (inert)
};

const TINT: Record<Color, { bg: string; fg: string; dot: string }> = {
  info: { bg: 'rgba(25,118,210,0.12)', fg: '#155fa8', dot: '#1976d2' },
  primary: { bg: 'rgba(21,83,158,0.12)', fg: '#15539e', dot: '#15539e' },
  success: { bg: 'rgba(21,101,192,0.12)', fg: '#1257a8', dot: '#1565c0' },
  warning: { bg: 'rgba(230,167,0,0.18)', fg: '#8a6300', dot: '#e6a700' },
  error: { bg: 'rgba(211,47,47,0.12)', fg: '#b5302c', dot: '#d32f2f' },
  default: { bg: 'rgba(90,107,123,0.12)', fg: '#566472', dot: '#7d8a99' },
};

export default function StatusChip({ status }: { status: string }) {
  const color = COLORS[status] ?? 'default';
  const t = TINT[color];
  return (
    <Chip
      size="small"
      color={color}
      label={status}
      icon={
        <Box
          component="span"
          sx={{ width: 7, height: 7, borderRadius: '50%', bgcolor: t.dot, ml: '2px' }}
        />
      }
      sx={{
        bgcolor: t.bg,
        color: t.fg,
        border: 'none',
        fontWeight: 600,
        letterSpacing: '0.01em',
        '& .MuiChip-icon': { ml: '6px', mr: '-4px' },
      }}
    />
  );
}
