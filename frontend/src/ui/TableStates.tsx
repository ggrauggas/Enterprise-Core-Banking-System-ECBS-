import TableRow from '@mui/material/TableRow';
import TableCell from '@mui/material/TableCell';
import Skeleton from '@mui/material/Skeleton';
import Box from '@mui/material/Box';
import Typography from '@mui/material/Typography';
import InboxOutlinedIcon from '@mui/icons-material/InboxOutlined';

/** Skeleton placeholder rows that match the column layout while data loads. */
export function SkeletonRows({ rows = 6, cols }: { rows?: number; cols: number }) {
  return (
    <>
      {Array.from({ length: rows }).map((_, r) => (
        <TableRow key={r}>
          {Array.from({ length: cols }).map((_, c) => (
            <TableCell key={c}>
              <Skeleton variant="text" width={c === 0 ? 24 : `${55 + ((c * 7) % 35)}%`} />
            </TableCell>
          ))}
        </TableRow>
      ))}
    </>
  );
}

/** Composed empty state shown inside a table body when there is no data. */
export function EmptyRow({ cols, message }: { cols: number; message: string }) {
  return (
    <TableRow>
      <TableCell colSpan={cols} sx={{ borderBottom: 0, py: 7 }}>
        <Box
          sx={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            gap: 1,
            color: 'text.secondary',
          }}
        >
          <InboxOutlinedIcon sx={{ fontSize: 34, color: 'text.disabled' }} />
          <Typography variant="body2">{message}</Typography>
        </Box>
      </TableCell>
    </TableRow>
  );
}
