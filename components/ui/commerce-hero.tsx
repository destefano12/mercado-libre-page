"use client";

/*
 * Commerce Hero · 21st.dev (@bankkroll/commerce-hero), adaptado.
 *
 * El original junta navbar, hero y grilla de categorías en un solo bloque con
 * textos fijos. Acá se separa en dos piezas reutilizables:
 *  - CommerceHeader: la barra con marca, links, acciones y el menú móvil en Sheet.
 *  - CommerceHero: el panel con titular animado y las tarjetas de categoría con
 *    la esquina recortada y la flecha.
 * Todo el contenido entra por props, así la marca define textos e imágenes.
 */

import * as React from "react";
import { motion } from "framer-motion";
import { ArrowUpRight, Menu } from "lucide-react";
import { Sheet, SheetClose, SheetContent, SheetDescription, SheetHeader, SheetTitle, SheetTrigger } from "@/components/ui/sheet";
import { Button } from "@/components/ui/button";
import { Separator } from "@/components/ui/separator";
import { cn } from "@/lib/utils";

export type CommerceNavItem = { name: string; href: string };

export interface CommerceHeaderProps {
  brand: React.ReactNode;
  navigation: CommerceNavItem[];
  /** Acciones siempre visibles (carrito, búsqueda…). */
  actions?: React.ReactNode;
  /** Botón destacado de la derecha (en el original, "Log In"). */
  cta?: { label: string; href: string; external?: boolean };
  /** Contenido extra al pie del menú móvil. */
  mobileFooter?: React.ReactNode;
  activeHref?: string;
  /** Clases de la barra (en el original, la "pestaña" recortada sobre el hero). */
  barClassName?: string;
  sheetContainer?: HTMLElement | null;
  menuLabel?: string;
  menuDescription?: string;
  className?: string;
}

export function CommerceHeader({
  brand,
  navigation,
  actions,
  cta,
  mobileFooter,
  activeHref,
  barClassName,
  sheetContainer,
  menuLabel = "Menú",
  menuDescription,
  className,
}: CommerceHeaderProps) {
  const [abierto, setAbierto] = React.useState(false);
  return (
    <header className={cn("flex items-center", className)}>
      <div className={cn("flex w-full items-center gap-2 rounded-br-2xl bg-background/95 p-3 backdrop-blur-sm md:p-4 lg:w-auto lg:flex-1", barClassName)}>
        {brand}

        <nav className="ml-6 hidden items-center gap-1 lg:flex" aria-label="Principal">
          {navigation.map((item) => {
            const activo = activeHref === item.href;
            return (
              <Button
                key={item.href}
                asChild
                variant="link"
                className={cn("relative px-3 text-[15px] font-semibold text-foreground/75 no-underline hover:text-primary hover:no-underline", activo && "text-primary")}
              >
                <a href={item.href} aria-current={activo ? "true" : undefined}>
                  {item.name}
                  {activo && <motion.span layoutId="commerce-nav-activo" className="absolute inset-x-3 -bottom-0.5 h-0.5 rounded-full bg-[hsl(var(--accent-strong))]" />}
                </a>
              </Button>
            );
          })}
        </nav>

        <div className="ml-auto flex items-center gap-1.5">
          {actions}
          <Sheet open={abierto} onOpenChange={setAbierto}>
            <SheetTrigger asChild className="lg:hidden">
              <Button variant="ghost" size="icon" className="rounded-full hover:text-primary" aria-label={menuLabel}>
                <Menu className="h-5 w-5" />
              </Button>
            </SheetTrigger>
            <SheetContent
              side="left"
              container={sheetContainer}
              className="flex w-[300px] flex-col gap-0 border-r border-border/50 bg-background/95 p-0 backdrop-blur-md sm:w-[380px]"
              overlayClassName="bg-black/40 backdrop-blur-[2px]"
            >
              <SheetHeader className="border-b border-border/50 p-6 text-left">
                <SheetTitle className="flex items-center justify-between">{brand}</SheetTitle>
                {menuDescription && <SheetDescription>{menuDescription}</SheetDescription>}
              </SheetHeader>
              <nav className="flex flex-col space-y-1 p-6" aria-label={menuLabel}>
                {navigation.map((item) => (
                  <SheetClose asChild key={item.href}>
                    <Button asChild variant="ghost" className="h-12 justify-between px-3 text-base font-semibold hover:bg-accent/60 hover:text-primary">
                      <a href={item.href}>
                        {item.name}
                        <ArrowUpRight className="h-4 w-4 opacity-60" aria-hidden="true" />
                      </a>
                    </Button>
                  </SheetClose>
                ))}
              </nav>
              {mobileFooter && (
                <>
                  <Separator className="mx-6 w-auto" />
                  <div className="flex flex-col gap-4 p-6">{mobileFooter}</div>
                </>
              )}
              {cta && (
                <div className="mt-auto p-6">
                  <SheetClose asChild>
                    <Button asChild className="h-12 w-full rounded-full shadow-lg transition-all duration-300 hover:shadow-xl">
                      <a href={cta.href} {...(cta.external ? { target: "_blank", rel: "noopener noreferrer" } : {})}>
                        {cta.label}
                        <ArrowUpRight className="ml-1 h-4 w-4" aria-hidden="true" />
                      </a>
                    </Button>
                  </SheetClose>
                </div>
              )}
            </SheetContent>
          </Sheet>
        </div>
      </div>

      {cta && (
        <div className="ml-auto hidden items-center gap-4 pl-2 lg:flex">
          <Button asChild variant="secondary" className="group h-auto rounded-full bg-primary p-0 text-primary-foreground shadow-lg transition-all duration-300 hover:bg-primary/90 hover:shadow-xl">
            <a href={cta.href} {...(cta.external ? { target: "_blank", rel: "noopener noreferrer" } : {})}>
              <span className="py-2 pl-4 text-sm font-semibold">{cta.label}</span>
              <span className="m-1 ml-2 flex h-9 w-9 items-center justify-center rounded-full bg-background text-foreground transition-transform duration-300 group-hover:scale-110">
                <ArrowUpRight className="h-4 w-4" aria-hidden="true" />
              </span>
            </a>
          </Button>
        </div>
      )}
    </header>
  );
}

export type CommerceCategory = {
  title: string;
  subtitle?: string;
  media: React.ReactNode;
  href: string;
  onSelect?: () => void;
  tint?: string;
};

export interface CommerceHeroProps {
  eyebrow?: React.ReactNode;
  title: React.ReactNode;
  description?: React.ReactNode;
  actions?: React.ReactNode;
  /** Visual opcional a la derecha del titular. */
  aside?: React.ReactNode;
  /** Pie del panel (datos, reseñas…). */
  footer?: React.ReactNode;
  categories?: CommerceCategory[];
  className?: string;
  id?: string;
}

export function CommerceHero({ eyebrow, title, description, actions, aside, footer, categories = [], className, id }: CommerceHeroProps) {
  return (
    <div id={id} className={cn("relative mx-auto w-full max-w-7xl px-2 sm:px-4", className)}>
      <div className="relative overflow-hidden rounded-[calc(var(--radius)+12px)] bg-accent/50">
        <motion.section
          className={cn("relative grid w-full items-center gap-10 px-5 pb-12 pt-10 sm:px-10 md:pb-16 md:pt-14", aside && "lg:grid-cols-[1.1fr_0.9fr]")}
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, ease: "easeOut" }}
        >
          <div className={cn(!aside && "mx-auto text-center")}>
            {eyebrow && (
              <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.5, delay: 0.1 }} className="mb-5">
                {eyebrow}
              </motion.div>
            )}
            <motion.h1
              className="mb-6 text-[clamp(2.4rem,6vw,4.6rem)] font-semibold leading-[1.02] tracking-tight"
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, delay: 0.2, ease: "easeOut" }}
            >
              {title}
            </motion.h1>
            {description && (
              <motion.p
                className={cn("max-w-xl text-base leading-relaxed text-muted-foreground md:text-lg", !aside && "mx-auto")}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.6, delay: 0.4, ease: "easeOut" }}
              >
                {description}
              </motion.p>
            )}
            {actions && (
              <motion.div
                className={cn("mt-8 flex flex-wrap items-center gap-3", !aside && "justify-center")}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.6, delay: 0.55, ease: "easeOut" }}
              >
                {actions}
              </motion.div>
            )}
            {footer && (
              <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ duration: 0.6, delay: 0.75 }} className="mt-10">
                {footer}
              </motion.div>
            )}
          </div>
          {aside && <div className="relative">{aside}</div>}
        </motion.section>
      </div>

      {categories.length > 0 && (
        <div className="mx-auto mt-4 grid max-w-7xl grid-cols-2 gap-3 sm:mt-6 sm:gap-6 lg:grid-cols-4">
          {categories.map((category, index) => (
            <motion.div
              key={category.title}
              className="group relative min-h-[190px] w-full overflow-hidden rounded-[calc(var(--radius)+8px)] bg-muted/60 p-4 backdrop-blur-sm transition-all duration-500 sm:min-h-[260px] sm:p-6"
              style={category.tint ? { background: `color-mix(in srgb, ${category.tint} 14%, hsl(var(--secondary)))` } : undefined}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, delay: 0.3 + index * 0.1, ease: "easeOut" }}
            >
              <a href={category.href} onClick={category.onSelect} className="absolute inset-0 z-20 rounded-[inherit] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ring">
                <span className="relative z-10 block px-4 pt-4 text-left sm:px-6 sm:pt-6">
                  <span className="block text-[clamp(1.35rem,2.6vw,2rem)] font-semibold leading-tight text-primary transition-colors duration-300 group-hover:text-primary/85">
                    {category.title}
                  </span>
                  {category.subtitle && <span className="mt-1 block text-xs font-semibold text-muted-foreground sm:text-sm">{category.subtitle}</span>}
                </span>
                <span className="absolute inset-x-0 bottom-0 top-14 flex items-center justify-center p-4 sm:top-20" aria-hidden="true">
                  <span className="block h-full max-h-[150px] w-full max-w-[150px] opacity-95 transition-all duration-500 group-hover:-rotate-3 group-hover:scale-110 group-hover:opacity-100">
                    {category.media}
                  </span>
                </span>
                <span className="absolute bottom-0 right-0 z-10 flex h-14 w-14 items-center justify-center rounded-tl-xl border-l border-t border-border/50 bg-background/95 backdrop-blur-sm md:h-20 md:w-20">
                  <span className="absolute bottom-2 right-2 flex h-9 w-9 items-center justify-center rounded-full bg-secondary shadow-lg transition-all duration-300 group-hover:scale-110 group-hover:bg-primary group-hover:text-primary-foreground md:bottom-3 md:right-3 md:h-12 md:w-12">
                    <ArrowUpRight className="h-5 w-5" aria-hidden="true" />
                  </span>
                </span>
              </a>
            </motion.div>
          ))}
        </div>
      )}
    </div>
  );
}
