import '@/styles/globals.css';
import { Inter } from 'next/font/google';
import { SupabaseProvider } from '@supabase/auth-helpers-nextjs';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ThemeProvider } from '@/hooks/useTheme';

const inter = Inter({ subsets: ['latin'] });

export const metadata = {
  title: 'APIForge – Enterprise API Testing Platform',
  description: 'Build, test, and monitor APIs with a glass‑morphic UI.',
};

const queryClient = new QueryClient();

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={inter.className}>
      <body>
        <SupabaseProvider>
          <QueryClientProvider client={queryClient}>
            <ThemeProvider>{children}</ThemeProvider>
          </QueryClientProvider>
        </SupabaseProvider>
      </body>
    </html>
  );
}
