import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import * as strategiesApi from '@/api/strategies'
import type { Strategy } from '@/types'

export function useStrategies() {
  return useQuery({
    queryKey: ['strategies'],
    queryFn: strategiesApi.getStrategies,
  })
}

export function useStrategy(id: number) {
  return useQuery({
    queryKey: ['strategies', id],
    queryFn: () => strategiesApi.getStrategy(id),
    enabled: !!id,
  })
}

export function useCreateStrategy() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (data: Partial<Strategy>) => strategiesApi.createStrategy(data),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['strategies'] }),
  })
}

export function useUpdateStrategy() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: ({ id, data }: { id: number; data: Partial<Strategy> }) =>
      strategiesApi.updateStrategy(id, data),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['strategies'] }),
  })
}

export function useDeleteStrategy() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => strategiesApi.deleteStrategy(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['strategies'] }),
  })
}
