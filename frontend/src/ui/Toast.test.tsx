import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { ToastProvider, useToast } from './Toast';

function Consumer() {
  const toast = useToast();
  return (
    <button type="button" onClick={() => toast('Saved successfully', 'success')}>
      fire
    </button>
  );
}

describe('Toast', () => {
  it('shows a message when the toast is fired', async () => {
    const user = userEvent.setup();
    render(
      <ToastProvider>
        <Consumer />
      </ToastProvider>,
    );

    expect(screen.queryByText('Saved successfully')).not.toBeInTheDocument();
    await user.click(screen.getByText('fire'));
    expect(await screen.findByText('Saved successfully')).toBeInTheDocument();
  });

  it('default no-op context does not throw when used without a provider', () => {
    render(<Consumer />);
    expect(screen.getByText('fire')).toBeInTheDocument();
  });
});
