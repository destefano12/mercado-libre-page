"use client";

import * as React from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Plus } from "lucide-react";
import { cn } from "@/lib/utils";

// --- TYPES ---
export type PaymentMethod = {
  id: string | number;
  icon: React.ReactNode;
  label: string;
  description: string;
};

export interface PaymentMethodSelectorProps {
  title: string;
  /** Texto del botón de acción del encabezado. Si se omite junto con onActionClick, el botón no se muestra. */
  actionText?: string;
  methods: PaymentMethod[];
  defaultSelectedId?: string | number;
  onActionClick?: () => void;
  onSelectionChange?: (id: string | number) => void;
  className?: string;
}

// --- MAIN COMPONENT ---
export function PaymentMethodSelector({
  title,
  actionText,
  methods,
  defaultSelectedId,
  onActionClick,
  onSelectionChange,
  className,
}: PaymentMethodSelectorProps) {
  const [selectedId, setSelectedId] = React.useState(
    defaultSelectedId ?? (methods.length > 0 ? methods[0].id : null)
  );

  const handleSelect = (id: string | number) => {
    setSelectedId(id);
    if (onSelectionChange) {
      onSelectionChange(id);
    }
  };

  const containerVariants = {
    hidden: { opacity: 0 },
    visible: {
      opacity: 1,
      transition: { staggerChildren: 0.08 },
    },
  };

  const itemVariants = {
    hidden: { opacity: 0, y: 20 },
    visible: { opacity: 1, y: 0 },
  };

  return (
    <div className={cn("w-full max-w-md rounded-xl border bg-card text-card-foreground shadow-sm p-6", className)}>
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <h3 className="text-xl font-semibold leading-none tracking-tight">{title}</h3>
        {actionText && onActionClick && (
          <button
            type="button"
            onClick={onActionClick}
            className="flex items-center gap-1 text-sm font-medium text-primary hover:text-primary/80 transition-colors"
          >
            <Plus className="w-4 h-4" aria-hidden="true" />
            {actionText}
          </button>
        )}
      </div>

      {/* Payment Methods List */}
      <motion.div
        className="space-y-4"
        variants={containerVariants}
        initial="hidden"
        animate="visible"
        role="radiogroup"
        aria-label={title}
      >
        {methods.map((method) => {
          const isSelected = selectedId === method.id;
          return (
            <motion.div
              key={method.id}
              variants={itemVariants}
              onClick={() => handleSelect(method.id)}
              onKeyDown={(e) => {
                if (e.key === " " || e.key === "Enter") {
                  e.preventDefault();
                  handleSelect(method.id);
                }
              }}
              className="flex items-center p-4 rounded-lg border cursor-pointer transition-all duration-300 hover:bg-muted/50 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
              style={{
                borderColor: isSelected ? "hsl(var(--primary))" : "hsl(var(--border))",
                boxShadow: isSelected ? "0 0 0 2px hsl(var(--primary))" : "none",
              }}
              role="radio"
              aria-checked={isSelected}
              tabIndex={0}
            >
              <div className="flex-shrink-0">{method.icon}</div>
              <div className="ml-4 flex-grow">
                <p className="font-medium text-card-foreground">{method.label}</p>
                <p className="text-sm text-muted-foreground">{method.description}</p>
              </div>
              <div
                className="ml-4 flex h-6 w-6 items-center justify-center rounded-full border-2"
                style={{
                  borderColor: isSelected ? "hsl(var(--primary))" : "hsl(var(--border))",
                }}
              >
                <AnimatePresence>
                  {isSelected && (
                    <motion.div
                      initial={{ scale: 0 }}
                      animate={{ scale: 1 }}
                      exit={{ scale: 0 }}
                      className="h-3 w-3 rounded-full bg-primary"
                    />
                  )}
                </AnimatePresence>
              </div>
            </motion.div>
          );
        })}
      </motion.div>
    </div>
  );
}
