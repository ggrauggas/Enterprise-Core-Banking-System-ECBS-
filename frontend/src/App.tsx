import { NavLink, Navigate, Route, Routes } from 'react-router-dom';
import AppBar from '@mui/material/AppBar';
import Toolbar from '@mui/material/Toolbar';
import Typography from '@mui/material/Typography';
import Box from '@mui/material/Box';
import Drawer from '@mui/material/Drawer';
import List from '@mui/material/List';
import ListItemButton from '@mui/material/ListItemButton';
import ListItemIcon from '@mui/material/ListItemIcon';
import ListItemText from '@mui/material/ListItemText';
import Avatar from '@mui/material/Avatar';
import Chip from '@mui/material/Chip';
import Divider from '@mui/material/Divider';
import AccountBalanceIcon from '@mui/icons-material/AccountBalance';
import DashboardIcon from '@mui/icons-material/Dashboard';
import PeopleIcon from '@mui/icons-material/People';
import SavingsIcon from '@mui/icons-material/Savings';
import SwapHorizIcon from '@mui/icons-material/SwapHoriz';
import CreditCardIcon from '@mui/icons-material/CreditCard';
import RequestQuoteIcon from '@mui/icons-material/RequestQuote';
import FactCheckIcon from '@mui/icons-material/FactCheck';
import PersonIcon from '@mui/icons-material/Person';
import type { ReactElement } from 'react';

import Dashboard from './pages/Dashboard';
import Customers from './pages/Customers';
import Accounts from './pages/Accounts';
import Transactions from './pages/Transactions';
import Cards from './pages/Cards';
import Loans from './pages/Loans';
import Audit from './pages/Audit';

const DRAWER_WIDTH = 244;

interface NavItem {
  to: string;
  label: string;
  icon: ReactElement;
}

const NAV: NavItem[] = [
  { to: '/dashboard', label: 'Dashboard', icon: <DashboardIcon /> },
  { to: '/customers', label: 'Clientes', icon: <PeopleIcon /> },
  { to: '/accounts', label: 'Cuentas', icon: <SavingsIcon /> },
  { to: '/transactions', label: 'Transacciones', icon: <SwapHorizIcon /> },
  { to: '/cards', label: 'Tarjetas', icon: <CreditCardIcon /> },
  { to: '/loans', label: 'Préstamos', icon: <RequestQuoteIcon /> },
  { to: '/audit', label: 'Auditoría', icon: <FactCheckIcon /> },
];

export default function App() {
  return (
    <Box sx={{ display: 'flex' }}>
      <AppBar
        position="fixed"
        elevation={0}
        sx={{
          zIndex: (t) => t.zIndex.drawer + 1,
          background: 'linear-gradient(180deg, #103253 0%, #0d2740 100%)',
          borderBottom: '1px solid rgba(255,255,255,0.06)',
        }}
      >
        <Toolbar>
          <Avatar
            variant="rounded"
            sx={{ bgcolor: 'rgba(255,255,255,0.12)', mr: 1.5, width: 38, height: 38, borderRadius: 2 }}
          >
            <AccountBalanceIcon />
          </Avatar>
          <Box sx={{ flexGrow: 1, lineHeight: 1.1 }}>
            <Typography variant="h6" noWrap component="div" sx={{ fontWeight: 800, letterSpacing: '0.04em' }}>
              ECBS
            </Typography>
            <Typography variant="caption" sx={{ opacity: 0.65, letterSpacing: '0.01em' }}>
              Enterprise Core Banking System
            </Typography>
          </Box>
          <Chip
            avatar={
              <Avatar sx={{ bgcolor: 'secondary.main' }}>
                <PersonIcon sx={{ fontSize: 16 }} />
              </Avatar>
            }
            label="Operador"
            sx={{ color: '#fff', bgcolor: 'rgba(255,255,255,0.1)', fontWeight: 600 }}
          />
        </Toolbar>
      </AppBar>

      <Drawer
        variant="permanent"
        sx={{
          width: DRAWER_WIDTH,
          flexShrink: 0,
          [`& .MuiDrawer-paper`]: { width: DRAWER_WIDTH, boxSizing: 'border-box' },
        }}
      >
        <Toolbar />
        <Box sx={{ display: 'flex', flexDirection: 'column', height: '100%', overflow: 'auto' }}>
          <Typography
            variant="overline"
            sx={{ px: 3, pt: 2, pb: 0.5, color: 'text.secondary', letterSpacing: '0.12em' }}
          >
            Operaciones
          </Typography>
          <List sx={{ px: 0 }}>
            {NAV.map((item) => (
              <ListItemButton
                key={item.to}
                component={NavLink}
                to={item.to}
                sx={{
                  position: 'relative',
                  mx: 1.25,
                  my: 0.25,
                  borderRadius: 2.5,
                  color: 'text.secondary',
                  '& .MuiListItemIcon-root': { color: 'text.secondary', minWidth: 38 },
                  '& .MuiListItemText-primary': { fontSize: 14, fontWeight: 600 },
                  '&:hover': { bgcolor: 'rgba(21,83,158,0.05)' },
                  '&.active': {
                    bgcolor: 'rgba(21,83,158,0.08)',
                    color: 'primary.dark',
                    '& .MuiListItemIcon-root': { color: 'primary.dark' },
                    '& .MuiListItemText-primary': { fontWeight: 700 },
                    '&::before': {
                      content: '""',
                      position: 'absolute',
                      left: 4,
                      top: 9,
                      bottom: 9,
                      width: 3,
                      borderRadius: 3,
                      backgroundColor: 'primary.main',
                    },
                  },
                }}
              >
                <ListItemIcon>{item.icon}</ListItemIcon>
                <ListItemText primary={item.label} />
              </ListItemButton>
            ))}
          </List>

          <Box sx={{ flexGrow: 1 }} />
          <Divider />
          <Box sx={{ p: 2 }}>
            <Typography variant="caption" color="text.secondary" display="block">
              v1.0 · React · Spring Boot · COBOL
            </Typography>
            <Chip
              size="small"
              color="success"
              variant="outlined"
              label="● Sistema operativo"
              sx={{ mt: 1, '& .MuiChip-label': { fontSize: 11 } }}
            />
          </Box>
        </Box>
      </Drawer>

      <Box
        component="main"
        sx={{
          flexGrow: 1,
          p: { xs: 2, md: 4 },
          minHeight: '100dvh',
          maxWidth: 1480,
          mx: 'auto',
          width: '100%',
          bgcolor: 'background.default',
        }}
      >
        <Toolbar />
        <Routes>
          <Route path="/" element={<Navigate to="/dashboard" replace />} />
          <Route path="/dashboard" element={<Dashboard />} />
          <Route path="/customers" element={<Customers />} />
          <Route path="/accounts" element={<Accounts />} />
          <Route path="/transactions" element={<Transactions />} />
          <Route path="/cards" element={<Cards />} />
          <Route path="/loans" element={<Loans />} />
          <Route path="/audit" element={<Audit />} />
          <Route path="*" element={<Navigate to="/dashboard" replace />} />
        </Routes>
      </Box>
    </Box>
  );
}
