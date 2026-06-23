import { describe, expect, it } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { ConfirmProvider, useConfirm } from './ConfirmDialog';

function Harness({ onResult }: { onResult: (v: boolean) => void }) {
  const confirm = useConfirm();
  return (
    <button
      onClick={async () => onResult(await confirm({ title: 'Cerrar cuenta', message: '¿Seguro?' }))}
    >
      run
    </button>
  );
}

function setup() {
  const results: boolean[] = [];
  render(
    <ConfirmProvider>
      <Harness onResult={(v) => results.push(v)} />
    </ConfirmProvider>,
  );
  return results;
}

describe('ConfirmDialog', () => {
  it('resolves true when the user confirms', async () => {
    const user = userEvent.setup();
    const results = setup();

    await user.click(screen.getByText('run'));
    expect(await screen.findByText('Cerrar cuenta')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Confirmar' }));

    await waitFor(() => expect(results).toEqual([true]));
  });

  it('resolves false when the user cancels', async () => {
    const user = userEvent.setup();
    const results = setup();

    await user.click(screen.getByText('run'));
    await user.click(await screen.findByRole('button', { name: 'Cancelar' }));

    await waitFor(() => expect(results).toEqual([false]));
  });

  it('renders the contextual detail rows and custom confirm label', async () => {
    const user = userEvent.setup();
    function DetailHarness() {
      const confirm = useConfirm();
      return (
        <button
          onClick={() =>
            confirm({
              title: 'Cerrar cuenta',
              message: 'definitivo',
              confirmText: 'Cerrar cuenta',
              tone: 'danger',
              details: [{ label: 'IBAN', value: 'ES7620770024' }],
            })
          }
        >
          run
        </button>
      );
    }
    render(
      <ConfirmProvider>
        <DetailHarness />
      </ConfirmProvider>,
    );

    await user.click(screen.getByText('run'));
    expect(await screen.findByText('IBAN')).toBeInTheDocument();
    expect(screen.getByText('ES7620770024')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Cerrar cuenta' })).toBeInTheDocument();
  });
});
