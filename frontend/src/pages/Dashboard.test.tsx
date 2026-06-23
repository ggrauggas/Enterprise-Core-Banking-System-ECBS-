import { afterEach, describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import { api } from '../api/client';
import type { BankReport, AuditStats } from '../api/types';
import Dashboard from './Dashboard';

const bank: BankReport = {
  totalCustomers: 12,
  activeCustomers: 10,
  totalAccounts: 18,
  totalDeposits: 54000,
  activeLoans: 3,
  totalLoanAmount: 30000,
  activeCards: 7,
};

const stats: AuditStats = {
  totalEntries: 120,
  distinctUsers: 4,
  firstEvent: '2026-01-01',
  lastEvent: '2026-06-21',
  byEntity: [{ name: 'CUSTOMER', count: 40 }],
  byOperation: [{ name: 'CREATE', count: 30 }],
};

describe('Dashboard', () => {
  afterEach(() => vi.restoreAllMocks());

  it('renders the KPIs once the reports resolve', async () => {
    vi.spyOn(api, 'get').mockImplementation((url: string) => {
      if (url === '/reports/bank') return Promise.resolve({ data: bank } as never);
      return Promise.resolve({ data: stats } as never);
    });

    render(<Dashboard />);

    expect(await screen.findByText('Clientes activos')).toBeInTheDocument();
    expect(screen.getByText('10')).toBeInTheDocument(); // active customers
    expect(screen.getByText('Tarjetas activas')).toBeInTheDocument();
    // Audit distributions render the entity/operation name and its count separately.
    expect(screen.getByText('CUSTOMER')).toBeInTheDocument();
    expect(screen.getByText('40')).toBeInTheDocument();
    expect(screen.getByText('CREATE')).toBeInTheDocument();
    expect(screen.getByText('30')).toBeInTheDocument();
  });

  it('shows an error alert when a report fails', async () => {
    vi.spyOn(api, 'get').mockRejectedValue(new Error('backend down'));

    render(<Dashboard />);

    await waitFor(() => expect(screen.getByText(/backend down/)).toBeInTheDocument());
  });
});
