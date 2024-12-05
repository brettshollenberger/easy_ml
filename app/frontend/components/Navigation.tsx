import React, { useState } from 'react';
import { AlertContainer } from './AlertProvider';
import { Link, router, usePage } from "@inertiajs/react";
import { Brain, Database, HardDrive, ChevronRight, ChevronDown, Menu, Settings2 } from 'lucide-react';
import { ScrollArea } from './ui/scroll-area';
import { Separator } from './ui/separator';
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from './ui/collapsible';
import { cn } from '@/lib/utils';
import { mockDatasets, mockModels } from '../mockData';

export function NavLink({ 
  href, 
  className = (isActive: boolean) => "", // Add type annotation for isActive
  activeClassName = 'active', 
  children, 
  ...props 
}: {
  href: string;
  className?: (isActive: boolean) => string;
  activeClassName?: string;
  children: React.ReactNode;
  [key: string]: any;
}) {
  // Get the current URL path from Inertia's page object
  const { rootPath, url } = usePage().props;

  // Check if the current URL matches the `href` to apply the active class
  const isActive = url === href;
  let classes = className(isActive);

  return (
    <Link
      href={`${rootPath}${href}`}
      className={cn(classes, isActive && activeClassName)}
      {...props}
    >
      {children}
    </Link>
  );
}

interface NavItem {
  title: string;
  icon: React.ElementType;
  href: string;
  children?: NavItem[];
}

const navItems: NavItem[] = [
  {
    title: 'Models',
    icon: Brain,
    href: '/',
    children: [
      { title: 'All Models', icon: Brain, href: '/models' },
      { title: 'New Model', icon: Brain, href: '/models/new' }
    ]
  },
  {
    title: 'Datasources',
    icon: HardDrive,
    href: '/datasources',
    children: [
      { title: 'All Datasources', icon: HardDrive, href: '/datasources' },
      { title: 'New Datasource', icon: HardDrive, href: '/datasources/new' }
    ]
  },
  {
    title: 'Datasets',
    icon: Database,
    href: '/datasets',
    children: [
      { title: 'All Datasets', icon: Database, href: '/datasets' },
      { title: 'New Dataset', icon: Database, href: '/datasets/new' }
    ]
  }
];

function getBreadcrumbs(pathname: string): { title: string; href: string }[] {
  const { rootPath } = usePage().props; // Inject rootPath
  const paths = pathname.split('/').filter(Boolean);
  const breadcrumbs = [];
  let currentPath = rootPath; // Start with rootPath

  // Determine the root breadcrumb based on the first path segment
  if (paths.length === 0) {
    return [];
  }

  let firstSegment;
  let rootCrumb;
  if (['datasources', 'datasets', 'models', 'settings'].includes(paths[0])) {
    firstSegment = paths[0];
    rootCrumb = 0;
  } else {
    firstSegment = paths[1];
    rootCrumb = 1;
  }
  switch (firstSegment) {
    case 'models':
      breadcrumbs.push({ title: 'Models', href: `${rootPath}/models` });
      break;
    case 'datasources':
      breadcrumbs.push({ title: 'Datasources', href: `${rootPath}/datasources` });
      break;
    case 'datasets':
      breadcrumbs.push({ title: 'Datasets', href: `${rootPath}/datasets` });
      break;
    case 'settings':
      breadcrumbs.push({ title: 'Settings', href: `${rootPath}/settings` });
      break;
    default:
      breadcrumbs.push({ title: 'Models', href: `${rootPath}/models` });
  }

  // Add remaining breadcrumbs only if there are more segments
  for (let i = rootCrumb + 1; i < paths.length; i++) {
    const path = paths[i];
    currentPath += `/${paths[i]}`;
    
    // Handle special cases for IDs
    if (paths[i-1] === 'datasets' && path !== 'new') {
      breadcrumbs.push({ 
        title: 'Details', 
        href: currentPath 
      });
    } else if (paths[i-1] === 'models' && path !== 'new') {
      breadcrumbs.push({ 
        title: 'Details', 
        href: currentPath 
      });
    } else {
      const title = path === 'new' 
        ? 'New'
        : path === 'edit'
        ? 'Edit'
        : path.charAt(0).toUpperCase() + path.slice(1);
      breadcrumbs.push({ title, href: currentPath });
    }
  }

  return breadcrumbs;
}

interface NavigationProps {
  children: React.ReactNode;
}

export function Navigation({ children }: NavigationProps) {
  const [isSidebarOpen, setIsSidebarOpen] = useState(true);
  const [openSections, setOpenSections] = useState<string[]>(['Models']);
  const breadcrumbs = getBreadcrumbs(location.pathname);

  const toggleSection = (title: string) => {
    setOpenSections(prev =>
      prev.includes(title)
        ? prev.filter(t => t !== title)
        : [...prev, title]
    );
  };

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Sidebar */}
      <div
        className={cn(
          "fixed left-0 top-0 z-40 h-screen bg-white border-r transition-all duration-300",
          isSidebarOpen ? "w-64" : "w-16"
        )}
      >
        <div className="flex h-16 items-center border-b px-4">
          {isSidebarOpen ? (
            <>
              <Brain className="w-8 h-8 text-blue-600" />
              <h1 className="text-xl font-bold text-gray-900 ml-2">EasyML</h1>
            </>
          ) : (
            <Brain className="w-8 h-8 text-blue-600" />
          )}
          <button
            onClick={() => setIsSidebarOpen(!isSidebarOpen)}
            className="ml-auto p-2 hover:bg-gray-100 rounded-md"
          >
            <Menu className="w-4 h-4" />
          </button>
        </div>

        <ScrollArea className="h-[calc(100vh-4rem)] px-3">
          <div className="space-y-2 py-4">
            {navItems.map((section) => (
              <Collapsible
                key={section.title}
                open={openSections.includes(section.title)}
                onOpenChange={() => toggleSection(section.title)}
              >
                <CollapsibleTrigger className="flex items-center w-full p-2 hover:bg-gray-100 rounded-md">
                  <section.icon className="w-4 h-4" />
                  {isSidebarOpen && (
                    <>
                      <span className="ml-2 text-sm font-medium flex-1 text-left">
                        {section.title}
                      </span>
                      {openSections.includes(section.title) ? (
                        <ChevronDown className="w-4 h-4" />
                      ) : (
                        <ChevronRight className="w-4 h-4" />
                      )}
                    </>
                  )}
                </CollapsibleTrigger>
                <CollapsibleContent>
                  {isSidebarOpen && section.children?.map((item) => (
                    <NavLink
                      key={item.href}
                      href={item.href}
                      className={({ isActive }) => 
                        cn(
                          "flex items-center pl-8 pr-2 py-2 text-sm rounded-md",
                          isActive
                            ? "bg-blue-50 text-blue-600"
                            : "text-gray-600 hover:bg-gray-50"
                        )
                      }
                    >
                      <item.icon className="w-4 h-4" />
                      <span className="ml-2">{item.title}</span>
                    </NavLink>
                  ))}
                </CollapsibleContent>
              </Collapsible>
            ))}

            <Separator className="my-4" />

            {/* Settings Link */}
            <NavLink
              href="/settings"
              className={({ isActive }) =>
                cn(
                  "flex items-center w-full p-2 rounded-md",
                  isActive
                    ? "bg-blue-50 text-blue-600"
                    : "text-gray-600 hover:bg-gray-50"
                )
              }
            >
              <Settings2 className="w-4 h-4" />
              {isSidebarOpen && (
                <span className="ml-2 text-sm font-medium">Settings</span>
              )}
            </NavLink>
          </div>
        </ScrollArea>
      </div>

      {/* Main content */}
      <div
        className={cn(
          "transition-all duration-300",
          isSidebarOpen ? "ml-64" : "ml-16"
        )}
      >
        <AlertContainer />

        {/* Breadcrumbs */}
        <div className="h-16 border-b bg-white flex items-center px-4">
          <nav className="flex" aria-label="Breadcrumb">
            <ol className="flex items-center space-x-2">
              {breadcrumbs.map((crumb, index) => (
                <React.Fragment key={crumb.href}>
                  {index > 0 && (
                    <ChevronRight className="w-4 h-4 text-gray-400" />
                  )}
                  <li>
                    <Link
                      href={crumb.href}
                      className={cn(
                        "text-sm",
                        index === breadcrumbs.length - 1
                          ? "text-blue-600 font-medium"
                          : "text-gray-500 hover:text-gray-700"
                      )}
                    >
                      {crumb.title}
                    </Link>
                  </li>
                </React.Fragment>
              ))}
            </ol>
          </nav>
        </div>

        {/* Page content */}
        <main className="min-h-[calc(100vh-4rem)]">
          {children}
        </main>
      </div>
    </div>
  );
}