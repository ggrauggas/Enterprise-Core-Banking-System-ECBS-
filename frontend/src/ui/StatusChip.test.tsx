import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import StatusChip from './StatusChip';

describe('StatusChip', () => {
  it('renders the status label', () => {
    render(<StatusChip status="ACTIVE" />);
    expect(screen.getByText('ACTIVE')).toBeInTheDocument();
  });

  it('maps known statuses to a coloured chip', () => {
    const { container } = render(<StatusChip status="DELETED" />);
    expect(container.querySelector('.MuiChip-colorError')).toBeInTheDocument();
  });

  it('falls back to default colour for unknown statuses', () => {
    const { container } = render(<StatusChip status="WHATEVER" />);
    expect(container.querySelector('.MuiChip-colorDefault')).toBeInTheDocument();
    expect(screen.getByText('WHATEVER')).toBeInTheDocument();
  });
});
