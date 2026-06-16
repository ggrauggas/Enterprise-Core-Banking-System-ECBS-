import Chip from '@mui/material/Chip';

type Color = 'success' | 'default' | 'error' | 'warning' | 'info' | 'primary';

const COLORS: Record<string, Color> = {
  ACTIVE: 'success',
  INACTIVE: 'warning',
  DELETED: 'error',
  CLOSED: 'default',
  BLOCKED: 'warning',
  CANCELLED: 'error',
  REQUESTED: 'info',
  APPROVED: 'primary',
  REJECTED: 'error',
  PAID: 'default',
  DEFAULTED: 'error',
};

export default function StatusChip({ status }: { status: string }) {
  return <Chip size="small" label={status} color={COLORS[status] ?? 'default'} />;
}
