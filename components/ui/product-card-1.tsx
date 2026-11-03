"use client";

/*
 * Product Card · 21st.dev (@beratberkayg/product-card-1), adaptada.
 *
 * Se mantiene la estructura del original (Card + imagen con badges y favorito,
 * puntaje y nota de envío, precio, muestras de color y botón con estados
 * cargando → agregado), pero todo lo que era fijo pasó a props: la imagen es un
 * slot, los textos son traducibles y "agregar" llama al carrito real.
 * Se quitaron el carrusel y los talles porque el catálogo tiene una imagen por
 * variante y no maneja talles.
 */

import * as React from "react";
import { AnimatePresence, motion } from "framer-motion";
import { Check, Eye, Heart, Loader2, ShoppingBag, Star } from "lucide-react";
import { Card, CardContent, CardFooter } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";

export type ProductCardColor = { name: string; value: string };
export type ProductCardBadge = { label: string; className?: string };

export interface ProductCardProps {
  name: string;
  description?: string;
  price: string;
  originalPrice?: string;
  priceNote?: string;
  rating: number;
  reviewCount: number;
  /** Imagen o ilustración del producto. */
  media: React.ReactNode;
  /** Color de fondo del área de imagen (por ejemplo, el tono de la variante). */
  mediaTint?: string;
  badges?: ProductCardBadge[];
  colors?: ProductCardColor[];
  selectedColor?: string;
  onColorChange?: (name: string) => void;
  wishlisted?: boolean;
  onWishlistChange?: (value: boolean) => void;
  /** Recibe la posición del botón para animar el producto hacia el carrito. */
  onAddToCart: (origin: DOMRect | null) => void;
  onOpen?: () => void;
  shippingNote?: React.ReactNode;
  footnote?: React.ReactNode;
  labels?: Partial<typeof ETIQUETAS>;
  className?: string;
}

const ETIQUETAS = {
  add: "Agregar al carrito",
  adding: "Agregando…",
  added: "¡Agregado!",
  wishlistAdd: "Guardar en favoritos",
  wishlistRemove: "Quitar de favoritos",
  quickView: "Vista rápida",
  colors: "Variante",
  reviews: "opiniones",
};

export const ProductCard = React.forwardRef<HTMLDivElement, ProductCardProps>(function ProductCard(
  {
    name,
    description,
    price,
    originalPrice,
    priceNote,
    rating,
    reviewCount,
    media,
    mediaTint,
    badges = [],
    colors = [],
    selectedColor,
    onColorChange,
    wishlisted = false,
    onWishlistChange,
    onAddToCart,
    onOpen,
    shippingNote,
    footnote,
    labels,
    className,
  },
  ref,
) {
  const t = { ...ETIQUETAS, ...labels };
  const [isAddingToCart, setIsAddingToCart] = React.useState(false);
  const [isAddedToCart, setIsAddedToCart] = React.useState(false);
  const buttonRef = React.useRef<HTMLButtonElement>(null);
  const timers = React.useRef<ReturnType<typeof setTimeout>[]>([]);
  React.useEffect(() => () => timers.current.forEach(clearTimeout), []);

  const handleAddToCart = () => {
    if (isAddingToCart || isAddedToCart) return;
    setIsAddingToCart(true);
    timers.current.push(
      setTimeout(() => {
        onAddToCart(buttonRef.current?.getBoundingClientRect() ?? null);
        setIsAddingToCart(false);
        setIsAddedToCart(true);
        timers.current.push(setTimeout(() => setIsAddedToCart(false), 1600));
      }, 380),
    );
  };

  const selected = colors.find((c) => c.name === selectedColor) ?? colors[0];

  return (
    <Card
      ref={ref}
      className={cn(
        "group flex h-full w-full flex-col overflow-hidden rounded-[var(--radius)] border-border/70 bg-card text-card-foreground shadow-sm transition-all duration-300 hover:-translate-y-1 hover:shadow-xl",
        className,
      )}
    >
      {/* Imagen */}
      <div className="relative aspect-[4/3.6] overflow-hidden" style={{ background: mediaTint ? `radial-gradient(circle at 50% 60%, color-mix(in srgb, ${mediaTint} 10%, white) 0%, color-mix(in srgb, ${mediaTint} 12%, hsl(var(--secondary))) 72%)` : undefined }}>
        <button
          type="button"
          onClick={onOpen}
          className="absolute inset-0 flex items-center justify-center p-6 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ring"
          aria-label={`${t.quickView}: ${name}`}
        >
          <span className="block h-full w-full transition-transform duration-500 ease-out group-hover:scale-[1.06]">{media}</span>
          <span className="pointer-events-none absolute bottom-3 left-1/2 inline-flex -translate-x-1/2 translate-y-3 items-center gap-1.5 rounded-full bg-background/90 px-3 py-1.5 text-xs font-semibold opacity-0 shadow-sm backdrop-blur-sm transition-all duration-300 group-hover:translate-y-0 group-hover:opacity-100 group-focus-within:translate-y-0 group-focus-within:opacity-100">
            <Eye className="h-3.5 w-3.5" aria-hidden="true" />
            {t.quickView}
          </span>
        </button>

        {/* Badges */}
        {badges.length > 0 && (
          <div className="pointer-events-none absolute left-3 top-3 flex flex-col items-start gap-2">
            {badges.map((b) => (
              <Badge key={b.label} className={cn("shadow-sm", b.className)}>
                {b.label}
              </Badge>
            ))}
          </div>
        )}

        {/* Favorito */}
        {onWishlistChange && (
          <Button
            type="button"
            variant="secondary"
            size="icon"
            aria-pressed={wishlisted}
            aria-label={`${wishlisted ? t.wishlistRemove : t.wishlistAdd}: ${name}`}
            className={cn("absolute right-3 top-3 h-9 w-9 rounded-full bg-background/85 shadow-sm backdrop-blur-sm", wishlisted && "text-destructive")}
            onClick={() => onWishlistChange(!wishlisted)}
          >
            <motion.span key={String(wishlisted)} initial={{ scale: 0.4 }} animate={{ scale: 1 }} transition={{ type: "spring", stiffness: 500, damping: 15 }}>
              <Heart className={cn("h-4 w-4", wishlisted && "fill-current")} aria-hidden="true" />
            </motion.span>
          </Button>
        )}
      </div>

      {/* Contenido */}
      <CardContent className="flex-1 p-4 sm:p-5">
        <div className="space-y-3">
          <div>
            <div className="flex items-center gap-2">
              <div className="flex items-center">
                <Star className="h-3.5 w-3.5 fill-[hsl(var(--rating))] text-[hsl(var(--rating))]" aria-hidden="true" />
                <span className="ml-1 text-sm font-semibold">{rating.toFixed(1)}</span>
              </div>
              <span className="text-xs text-muted-foreground">
                ({reviewCount} {t.reviews})
              </span>
              {shippingNote && <span className="ml-auto text-right text-xs font-semibold text-[hsl(var(--success))]">{shippingNote}</span>}
            </div>
            <h3 className="mt-1.5 text-lg font-semibold leading-snug">
              <button type="button" onClick={onOpen} className="text-left hover:text-primary/80 focus-visible:outline-none focus-visible:underline">
                {name}
              </button>
            </h3>
            {description && <p className="mt-1 line-clamp-2 text-sm text-muted-foreground">{description}</p>}
          </div>

          {/* Precio */}
          <div>
            <div className="flex flex-wrap items-baseline gap-2">
              <span className="text-xl font-bold tracking-tight">{price}</span>
              {originalPrice && <span className="text-sm text-muted-foreground line-through">{originalPrice}</span>}
            </div>
            {priceNote && <p className="text-xs text-muted-foreground">{priceNote}</p>}
          </div>

          {/* Colores */}
          {colors.length > 1 && (
            <div className="space-y-1.5">
              <div className="text-xs text-muted-foreground">
                {t.colors}: <span className="font-semibold text-foreground">{selected?.name}</span>
              </div>
              <div className="flex gap-2" role="radiogroup" aria-label={`${t.colors} de ${name}`}>
                {colors.map((color) => {
                  const activo = selected?.name === color.name;
                  return (
                    <button
                      key={color.name}
                      type="button"
                      role="radio"
                      aria-checked={activo}
                      aria-label={color.name}
                      title={color.name}
                      className={cn(
                        "h-6 w-6 rounded-full transition-all",
                        activo ? "ring-2 ring-primary ring-offset-2 ring-offset-card" : "ring-1 ring-border hover:ring-primary",
                      )}
                      style={{ backgroundColor: color.value }}
                      onClick={() => onColorChange?.(color.name)}
                    />
                  );
                })}
              </div>
            </div>
          )}
        </div>
      </CardContent>

      {/* Pie */}
      <CardFooter className="flex-col items-stretch gap-2 p-4 pt-0 sm:p-5 sm:pt-0">
        <Button
          ref={buttonRef}
          type="button"
          className={cn("h-11 w-full rounded-full font-semibold transition-colors", isAddedToCart && "bg-[hsl(var(--success))] hover:bg-[hsl(var(--success))]")}
          onClick={handleAddToCart}
          aria-label={`${t.add}: ${name}`}
          aria-busy={isAddingToCart}
        >
          <AnimatePresence mode="wait" initial={false}>
            <motion.span
              key={isAddingToCart ? "adding" : isAddedToCart ? "added" : "idle"}
              className="inline-flex items-center gap-2"
              initial={{ y: 10, opacity: 0 }}
              animate={{ y: 0, opacity: 1 }}
              exit={{ y: -10, opacity: 0 }}
              transition={{ duration: 0.16 }}
            >
              {isAddingToCart ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin" aria-hidden="true" />
                  {t.adding}
                </>
              ) : isAddedToCart ? (
                <>
                  <Check className="h-4 w-4" aria-hidden="true" />
                  {t.added}
                </>
              ) : (
                <>
                  <ShoppingBag className="h-4 w-4" aria-hidden="true" />
                  {t.add}
                </>
              )}
            </motion.span>
          </AnimatePresence>
        </Button>
        {footnote && <p className="text-center text-xs font-semibold text-[hsl(var(--warning))]">{footnote}</p>}
      </CardFooter>
    </Card>
  );
});
