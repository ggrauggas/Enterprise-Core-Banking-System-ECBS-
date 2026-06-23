import TablePagination from '@mui/material/TablePagination';
import type { ChangeEvent } from 'react';

interface Props {
  count: number;
  page: number;
  rowsPerPage: number;
  onPageChange: (event: unknown, page: number) => void;
  onRowsPerPageChange: (event: ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => void;
}

/** Spanish-localised pagination bar attached to the bottom of a data table. */
export default function DataTablePagination({
  count,
  page,
  rowsPerPage,
  onPageChange,
  onRowsPerPageChange,
}: Props) {
  return (
    <TablePagination
      component="div"
      count={count}
      page={page}
      rowsPerPage={rowsPerPage}
      onPageChange={onPageChange}
      onRowsPerPageChange={onRowsPerPageChange}
      rowsPerPageOptions={[10, 25, 50, 100]}
      labelRowsPerPage="Filas por página"
      labelDisplayedRows={({ from, to, count: c }) => `${from}–${to} de ${c}`}
      sx={{ borderTop: 1, borderColor: 'divider' }}
    />
  );
}
