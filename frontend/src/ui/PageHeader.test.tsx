import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import PageHeader from './PageHeader';

describe('PageHeader', () => {
  it('renders the title', () => {
    render(<PageHeader title="Clientes" />);
    expect(screen.getByText('Clientes')).toBeInTheDocument();
  });

  it('renders subtitle and action when provided', () => {
    render(<PageHeader title="Cuentas" subtitle="Listado" action={<button>Nuevo</button>} />);
    expect(screen.getByText('Listado')).toBeInTheDocument();
    expect(screen.getByText('Nuevo')).toBeInTheDocument();
  });
});
